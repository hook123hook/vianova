(function () {
  const root = document.querySelector('[data-pay-desk]');
  if (!root) return;

  const lang = root.dataset.lang || 'tr';
  const t = lang === 'tr' ? {
    creating: 'Fatura oluşturuluyor…',
    newInvoice: 'Yeni Monero faturası',
    noAddress: 'Monero adres havuzu henüz hazır değil (bridge kurulumu gerekli).',
    fail: 'Fatura oluşturulamadı. Lütfen tekrar deneyin.',
    rate: 'Kur: 1 XMR ≈ {r} EUR · {e} EUR karşılığı',
    expiresIn: 'Fatura geçerliliği: ~{m} dk',
    expired: 'Fatura süresi doldu. Yeni fatura oluşturun.',
    waiting: 'Ödeme bekleniyor…',
    partial: 'Ödeme alındı, onay bekleniyor',
    paid: 'Ödendi ve onaylandı ✓',
    copyAddr: 'Adresi kopyala',
    copied: 'Kopyalandı',
    copyIban: 'IBAN\'ı kopyala',
    ibanCopied: 'Kopyalandı'
  } : {
    creating: 'Creating invoice…',
    newInvoice: 'New Monero invoice',
    noAddress: 'The Monero address pool is not ready yet (owner must run the bridge setup).',
    fail: 'Could not create invoice. Please retry.',
    rate: 'Rate: 1 XMR ≈ {r} EUR · covers {e} EUR',
    expiresIn: 'Invoice valid for ~{m} min',
    expired: 'Invoice expired. Create a new one.',
    waiting: 'Waiting for payment…',
    partial: 'Payment received, awaiting confirmations',
    paid: 'Payment credited ✓',
    copyAddr: 'Copy address',
    copied: 'Copied',
    copyIban: 'Copy IBAN',
    ibanCopied: 'Copied'
  };

  const q = s => root.querySelector(s);

  const FEES = { horizon: 7500, continental: 10000, signature: 15000, unity: 20000 };
  const NAMES = { horizon: 'Horizon', continental: 'Continental', signature: 'Signature', unity: 'Unity' };
  const PREASSESSMENT_FEE = 1000;

  let packId = 'horizon';
  let payOption = 'preassessment';
  let payMethod = 'monero';
  let invoiceId = null;
  let pollTick = null;
  let expireTimer = null;

  function fmt(n, decimals) {
    return n.toLocaleString(lang === 'tr' ? 'tr-TR' : 'en-US', { maximumFractionDigits: decimals || 2 });
  }
  function fmtMoney(n) {
    return new Intl.NumberFormat(lang === 'tr' ? 'tr-TR' : 'en-US', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 }).format(n);
  }

  /* ── Option pills (preassessment / full) ── */
  const optionPills = root.querySelectorAll('[data-option-pills] [data-option]');
  const packPillsWrap = q('[data-full-options]');
  const packPills = root.querySelectorAll('[data-pack-pills] [data-pack]');
  const payLabel = q('[data-pay-label]');
  const payEur = q('[data-pay-eur]');

  function getAmount() {
    return payOption === 'preassessment' ? PREASSESSMENT_FEE : (FEES[packId] || FEES.horizon);
  }
  function getLabel() {
    if (payOption === 'preassessment') {
      return lang === 'tr' ? 'Ön Değerlendirme Ücreti' : 'Pre-Assessment Fee';
    }
    return (NAMES[packId] || 'Horizon') + ' ' + (lang === 'tr' ? 'Paketi' : 'Package');
  }

  function updatePayDisplay() {
    if (payLabel) payLabel.textContent = getLabel();
    if (payEur) payEur.textContent = fmtMoney(getAmount());
    if (packPillsWrap) packPillsWrap.hidden = payOption === 'preassessment';
  }

  optionPills.forEach(btn => {
    btn.addEventListener('click', () => {
      payOption = btn.dataset.option;
      optionPills.forEach(b => b.classList.toggle('is-on', b.dataset.option === payOption));
      updatePayDisplay();
    });
  });

  /* ── Package pills ── */
  packPills.forEach(btn => {
    btn.addEventListener('click', () => {
      packId = btn.dataset.pack;
      packPills.forEach(b => b.classList.toggle('is-on', b.dataset.pack === packId));
      try { localStorage.setItem('vianova_selected_package', packId); } catch (e) {}
      updatePayDisplay();
    });
  });

  /* ── Method pills (monero / iban) ── */
  const methodPills = root.querySelectorAll('[data-method-pills] [data-method]');
  const moneroSection = q('[data-monero-section]');
  const ibanSection = q('[data-iban-section]');

  methodPills.forEach(btn => {
    btn.addEventListener('click', () => {
      payMethod = btn.dataset.method;
      methodPills.forEach(b => b.classList.toggle('is-on', b.dataset.method === payMethod));
      if (moneroSection) moneroSection.hidden = payMethod !== 'monero';
      if (ibanSection) ibanSection.hidden = payMethod !== 'iban';
    });
  });

  /* ── IBAN copy ── */
  const ibanCopyBtn = q('[data-iban-copy]');
  if (ibanCopyBtn) {
    ibanCopyBtn.addEventListener('click', async () => {
      try {
        await navigator.clipboard.writeText('GB26 PROP 5247 4535 8845 75');
        ibanCopyBtn.textContent = t.ibanCopied;
        setTimeout(() => { ibanCopyBtn.textContent = t.copyIban; }, 1600);
      } catch (e) {}
    });
  }

  /* ── Monero invoice creation ── */
  const xmrEls = {
    create: q('[data-xmr-create]'),
    wrap: q('[data-xmr]'),
    eur: q('[data-xmr-eur]'),
    amount: q('[data-xmr-amount]'),
    rate: q('[data-xmr-rate]'),
    qr: q('[data-xmr-qr]'),
    address: q('[data-xmr-address]'),
    copy: q('[data-xmr-copy]'),
    expires: q('[data-xmr-expires]'),
    status: q('[data-xmr-status]'),
    error: q('[data-xmr-error]')
  };

  if (xmrEls.create) {
    xmrEls.create.addEventListener('click', async () => {
      if (xmrEls.error) { xmrEls.error.textContent = ''; xmrEls.error.hidden = true; }
      xmrEls.create.disabled = true;
      xmrEls.create.textContent = t.creating;
      try {
        const resp = await fetch('/api/xmr/invoice/', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ package_id: payOption === 'preassessment' ? 'preassessment' : packId })
        });
        const data = await resp.json().catch(() => null);
        if (!resp.ok) {
          if (xmrEls.error) {
            xmrEls.error.textContent = (data && data.error === 'NO_ADDRESS_AVAILABLE') ? t.noAddress : ((data && data.message) || t.fail);
            xmrEls.error.hidden = false;
          }
          return;
        }
        renderXmr(data);
      } catch (e) {
        if (xmrEls.error) { xmrEls.error.textContent = t.fail; xmrEls.error.hidden = false; }
      } finally {
        xmrEls.create.disabled = false;
        xmrEls.create.textContent = t.newInvoice;
      }
    });
  }

  function renderXmr(inv) {
    invoiceId = inv.id;
    if (xmrEls.wrap) xmrEls.wrap.hidden = false;
    if (xmrEls.eur) xmrEls.eur.textContent = fmtMoney(inv.amount_eur);
    if (xmrEls.amount) xmrEls.amount.textContent = fmt(inv.amount_xmr, 6) + ' XMR';
    if (xmrEls.rate) xmrEls.rate.textContent = t.rate.replace('{r}', fmt(inv.fx_rate, 2)).replace('{e}', fmtMoney(inv.amount_eur));
    if (xmrEls.qr) xmrEls.qr.src = 'https://api.qrserver.com/v1/create-qr-code/?size=260x260&margin=4&data=' + encodeURIComponent(inv.qr);
    if (xmrEls.address) xmrEls.address.textContent = inv.address;
    startExpiry(inv.expires_at);
    startPoll();
  }

  function startExpiry(iso) {
    clearInterval(expireTimer);
    expireTimer = setInterval(() => {
      const left = new Date(iso).getTime() - Date.now();
      if (left <= 0) {
        if (xmrEls.expires) xmrEls.expires.textContent = t.expired;
        if (xmrEls.status) xmrEls.status.textContent = t.expired;
        clearInterval(expireTimer);
        stopPoll();
        return;
      }
      if (xmrEls.expires) xmrEls.expires.textContent = t.expiresIn.replace('{m}', String(Math.ceil(left / 60000)));
    }, 30000);
    if (xmrEls.expires) xmrEls.expires.textContent = t.expiresIn.replace('{m}', String(Math.max(1, Math.ceil((new Date(iso).getTime() - Date.now()) / 60000))));
  }

  async function check() {
    if (!invoiceId) return;
    try {
      const r = await fetch('/api/xmr/status/?id=' + encodeURIComponent(invoiceId));
      if (!r.ok) return;
      const s = await r.json();
      if (!xmrEls.status) return;
      if (s.status === 'credited') {
        xmrEls.status.textContent = t.paid;
        xmrEls.status.classList.add('is-ok');
        stopPoll();
        clearInterval(expireTimer);
      } else if (s.received_amount_xmr != null) {
        xmrEls.status.textContent = t.partial + ' (' + (s.confirmations || 0) + '/10)';
      } else {
        xmrEls.status.textContent = t.waiting;
      }
    } catch (e) {}
  }
  function startPoll() { stopPoll(); check(); pollTick = setInterval(check, 12000); }
  function stopPoll() { if (pollTick) { clearInterval(pollTick); pollTick = null; } }

  if (xmrEls.copy) {
    xmrEls.copy.addEventListener('click', async () => {
      if (!xmrEls.address || !xmrEls.address.textContent) return;
      try {
        await navigator.clipboard.writeText(xmrEls.address.textContent);
        xmrEls.copy.textContent = t.copied;
        setTimeout(() => { xmrEls.copy.textContent = t.copyAddr; }, 1600);
      } catch (e) {}
    });
  }

  /* ── Init ── */
  const urlPack = new URLSearchParams(window.location.search).get('package');
  const storedPack = (() => { try { return localStorage.getItem('vianova_selected_package'); } catch (e) { return null; } })();
  if (urlPack || storedPack) {
    packId = urlPack || storedPack;
    if (!FEES[packId]) packId = 'horizon';
    packPills.forEach(b => b.classList.toggle('is-on', b.dataset.pack === packId));
  }
  updatePayDisplay();
})();
