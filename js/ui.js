/**
 * Custom UI Components
 * Pengganti alert/confirm/prompt bawaan browser
 */
export const UI = {
  
  /**
   * Custom Modal — menggantikan window.alert / confirm
   */
  modal({ 
    title = 'Pemberitahuan', 
    message = '', 
    icon = 'info', 
    confirmText = 'OK', 
    cancelText = null,
    variant = 'primary' 
  } = {}) {
    return new Promise((resolve) => {
      const root = document.getElementById('modalRoot');
      root.innerHTML = '';
      
      const iconSvg = {
        info: '<circle cx="12" cy="12" r="10"></circle><line x1="12" y1="16" x2="12" y2="12"></line><line x1="12" y1="8" x2="12.01" y2="8"></line>',
        success: '<path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path><polyline points="22 4 12 14.01 9 11.01"></polyline>',
        warning: '<path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"></path><line x1="12" y1="9" x2="12" y2="13"></line><line x1="12" y1="17" x2="12.01" y2="17"></line>',
        danger: '<circle cx="12" cy="12" r="10"></circle><line x1="15" y1="9" x2="9" y2="15"></line><line x1="9" y1="9" x2="15" y2="15"></line>'
      };
      
      const backdrop = document.createElement('div');
      backdrop.className = 'modal-backdrop';
      
      const dialog = document.createElement('div');
      dialog.className = 'modal-dialog';
      dialog.setAttribute('role', 'alertdialog');
      dialog.setAttribute('aria-modal', 'true');
      
      dialog.innerHTML = `
        <div class="modal-icon ${icon}">
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            ${iconSvg[icon] || iconSvg.info}
          </svg>
        </div>
        <h2 class="modal-title">${this._escape(title)}</h2>
        <div class="modal-body">${this._escape(message)}</div>
        <div class="modal-actions">
          ${cancelText ? `<button class="btn btn-secondary" data-action="cancel">${this._escape(cancelText)}</button>` : ''}
          <button class="btn btn-${variant}" data-action="confirm">${this._escape(confirmText)}</button>
        </div>
      `;
      
      root.appendChild(backdrop);
      root.appendChild(dialog);
      
      requestAnimationFrame(() => {
        root.classList.add('visible');
        root.setAttribute('aria-hidden', 'false');
        dialog.querySelector('button').focus();
      });
      
      const close = (value) => {
        root.classList.remove('visible');
        root.setAttribute('aria-hidden', 'true');
        setTimeout(() => { root.innerHTML = ''; }, 250);
        resolve(value);
      };
      
      dialog.querySelector('[data-action="confirm"]').onclick = () => close(true);
      const cancelBtn = dialog.querySelector('[data-action="cancel"]');
      if (cancelBtn) cancelBtn.onclick = () => close(false);
      backdrop.onclick = () => cancelBtn ? close(false) : close(true);
      
      const onKey = (e) => {
        if (e.key === 'Escape') {
          document.removeEventListener('keydown', onKey);
          cancelBtn ? close(false) : close(true);
        }
      };
      document.addEventListener('keydown', onKey);
    });
  },
  
  /**
   * Toast Notification
   */
  toast(message, { type = 'info', duration = 3000 } = {}) {
    const root = document.getElementById('toastRoot');
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.setAttribute('role', 'status');
    
    const icons = {
      info: 'ℹ',
      success: '✓',
      warning: '⚠',
      danger: '✕'
    };
    
    toast.innerHTML = `
      <span style="font-weight:700;font-size:16px;">${icons[type]}</span>
      <span style="flex:1">${this._escape(message)}</span>
    `;
    
    root.appendChild(toast);
    
    setTimeout(() => {
      toast.classList.add('hiding');
      setTimeout(() => toast.remove(), 250);
    }, duration);
  },
  
  _escape(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
  }
};