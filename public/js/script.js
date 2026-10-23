/* ============================================================
   AGON — Shared JavaScript
   Theme toggle, sidebar, profile modal, header interactions
   ============================================================ */

document.addEventListener('DOMContentLoaded', function () {

  // ─── Theme Management ────────────────────────────────────
  const savedTheme = localStorage.getItem('agon-theme') || 'light';
  document.documentElement.setAttribute('data-theme', savedTheme);
  updateThemeIcons(savedTheme);
  updateThemeLogos(savedTheme);

  document.querySelectorAll('.theme-toggle').forEach(btn => {
    btn.addEventListener('click', () => {
      const current = document.documentElement.getAttribute('data-theme');
      const next = current === 'dark' ? 'light' : 'dark';
      document.documentElement.setAttribute('data-theme', next);
      localStorage.setItem('agon-theme', next);
      updateThemeIcons(next);
      updateThemeLogos(next);
      
      // Dispatch custom event for charts or dynamic components to react
      window.dispatchEvent(new CustomEvent('agonThemeChanged', { detail: { theme: next } }));
    });
  });

  function updateThemeIcons(theme) {
    document.querySelectorAll('.theme-toggle').forEach(btn => {
      const icon = btn.querySelector('i');
      if (icon) {
        icon.className = theme === 'dark'
          ? 'fa-solid fa-sun'
          : 'fa-solid fa-moon';
      }
    });
    // Update the toggle switch in profile modal settings
    const themeSwitch = document.getElementById('theme-switch');
    if (themeSwitch) {
      themeSwitch.checked = theme === 'dark';
    }
  }

  function updateThemeLogos(theme) {
    const isDark = theme === 'dark';

    // 1. Swap the logo image for dark and light themes.
    const logoImgs = document.querySelectorAll('img[alt="AGON"], img[alt="Agon"], img[alt="Logo"], .agon-logo-img');
    logoImgs.forEach(img => {
      const currentSrc = img.getAttribute('src');
      if (!currentSrc) return;
      if (isDark) {
        if (currentSrc.includes('agon-light.png')) {
          img.src = currentSrc.replace('agon-light.png', 'agon-white.png');
        }
      } else {
        if (currentSrc.includes('agon-white.png')) {
          img.src = currentSrc.replace('agon-white.png', 'agon-light.png');
        }
      }
    });

    // 2. Ensure brand text next to the logo is white in dark mode and agon blue in light mode
    document.querySelectorAll('.sidebar a span, header a span, .auth-card a span, a.group span, .agon-brand-text').forEach(span => {
      const txt = span.textContent.trim().toUpperCase();
      if (txt === 'AGON') {
        span.style.color = isDark ? '#FFFFFF' : 'var(--color-blue)';
      }
    });
  }

  // Theme switch inside profile modal
  const themeSwitch = document.getElementById('theme-switch');
  if (themeSwitch) {
    themeSwitch.addEventListener('change', () => {
      const next = themeSwitch.checked ? 'dark' : 'light';
      document.documentElement.setAttribute('data-theme', next);
      localStorage.setItem('agon-theme', next);
      updateThemeIcons(next);
      updateThemeLogos(next);
      window.dispatchEvent(new CustomEvent('agonThemeChanged', { detail: { theme: next } }));
    });
  }

  // ─── Sidebar Active State ─────────────────────────────────
  const currentPage = window.location.pathname.split('/').pop() || 'index.html';
  const pageKey = currentPage.replace('.html', '');
  const noticeCopy = {
    index: 'Demonstracao: questoes e acertos usam seus dados. Horas, metas e historico semanal ainda nao estao integrados.',
    dashboard: 'Demonstracao: questoes e acertos usam seus dados. Horas, metas e historico semanal ainda nao estao integrados.',
    questoes: 'Banco demonstrativo: estas questoes sao exemplos e nao representam uma fonte oficial.',
    desempenho: 'Demonstracao: questoes e acertos usam seus dados. Sequencia, horas, simulados e comparativos ainda nao estao integrados.',
    'planos-estudo': 'Demonstracao: as recomendacoes consideram sua atividade; a agenda exibida pode conter exemplos.',
    aulas: 'Prototipo: conteudo das aulas e progresso ainda nao sao salvos na sua conta.',
    materiais: 'Prototipo: materiais e downloads ainda nao estao ligados a um catalogo gerenciado.',
    estudos: 'Prototipo: sessoes e progresso de estudo ainda nao sao salvos na sua conta.',
    simulados: 'Prototipo: simulados sao exemplos e os resultados ainda nao sao salvos.',
    comunidade: 'Prototipo: publicacoes e classificacoes sao exemplos, nao dados de uma comunidade ativa.',
    conquistas: 'Prototipo: conquistas e classificacoes sao exemplos, nao calculados para a sua conta.',
    configuracoes: 'Prototipo: alteracoes de perfil, preferencias e pagamentos nao sao persistidas.',
    'em-breve': 'Prototipo: estes recursos ainda nao estao disponiveis.'
  }[pageKey];
  if (noticeCopy) {
    const main = document.querySelector('main');
    if (main) {
      const notice = document.createElement('div');
      notice.setAttribute('role', 'status');
      notice.textContent = noticeCopy;
      notice.style.cssText = 'margin: 12px 20px; padding: 10px 14px; border-radius: 10px; background: #fff7ed; color: #9a3412; font-size: 12px;';
      main.prepend(notice);
    }
  }

  document.querySelectorAll('.nav-item').forEach(item => {
    const href = item.getAttribute('href');
    if (href === currentPage || (currentPage === '' && href === 'index.html')) {
      item.classList.add('active');
    }
  });

  // ─── Mobile Sidebar Toggle ───────────────────────────────
  const sidebar = document.querySelector('.sidebar');
  const sidebarOverlay = document.querySelector('.sidebar-overlay');
  const menuBtn = document.getElementById('mobile-menu-btn');

  if (menuBtn && sidebar) {
    menuBtn.addEventListener('click', () => {
      sidebar.classList.toggle('open');
      if (sidebarOverlay) sidebarOverlay.classList.toggle('active');
    });
  }
  if (sidebarOverlay) {
    sidebarOverlay.addEventListener('click', () => {
      sidebar.classList.remove('open');
      sidebarOverlay.classList.remove('active');
    });
  }

  // ─── Profile Modal & Logout ──────────────────────────────
  function openModal() {
    const modal = document.getElementById('profile-modal');
    if (modal) {
      modal.classList.add('active');
      document.body.style.overflow = 'hidden';
      // Sync theme switch state if present in modal
      const curTheme = document.documentElement.getAttribute('data-theme') || 'light';
      const sw = document.getElementById('theme-switch');
      if (sw) sw.checked = (curTheme === 'dark');
    }
  }

  function closeModal() {
    const modal = document.getElementById('profile-modal');
    if (modal) {
      modal.classList.remove('active');
      document.body.style.overflow = '';
    }
  }

  // Delegação de eventos para robustez total (funciona mesmo se o modal for renderizado depois)
  document.addEventListener('click', (e) => {
    // Abrir Modal de Perfil
    const openBtn = e.target.closest('.open-profile-modal');
    if (openBtn) {
      e.preventDefault();
      openModal();
      return;
    }

    // Fechar Modal (botão X)
    const closeBtn = e.target.closest('#modal-close-btn, .modal-close-btn');
    if (closeBtn) {
      e.preventDefault();
      closeModal();
      return;
    }

    // Fechar Modal clicando no backdrop escuro
    const modal = document.getElementById('profile-modal');
    if (modal && e.target === modal) {
      closeModal();
      return;
    }

    // Navegação pelas abas do modal
    const tabBtn = e.target.closest('.modal-tab');
    if (tabBtn) {
      e.preventDefault();
      const target = tabBtn.dataset.tab;
      document.querySelectorAll('.modal-tab').forEach(t => t.classList.remove('active'));
      document.querySelectorAll('.modal-tab-content').forEach(c => c.classList.remove('active'));
      tabBtn.classList.add('active');
      const content = document.getElementById('tab-' + target);
      if (content) content.classList.add('active');
      return;
    }

    // Ação de Logout (Sair da Conta)
    const logoutBtn = e.target.closest('.btn-logout, #modal-logout-btn, [data-action="logout"]');
    if (logoutBtn) {
      e.preventDefault();
      if (confirm('Deseja realmente sair da sua conta Agon?')) {
        fetch('/api/logout', { method: 'POST' })
          .finally(() => {
            window.location.href = '/login.html';
          });
      }
      return;
    }
  });

  // Fechar modal com tecla ESC
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeModal();
  });

  // Sincronizar nome e e-mail do usuário logado no header e no modal
  fetch('/api/check-auth')
    .then(r => r.json())
    .then(data => {
      const user = data.usuario;
      if (user && user.nome) {
        document.querySelectorAll('.user-name-display, .student-name-display').forEach(el => {
          el.textContent = user.nome;
        });
        document.querySelectorAll('.open-profile-modal').forEach(container => {
          const displayName = container.querySelector('p');
          if (displayName) displayName.textContent = user.nome;
        });
        const composer = document.getElementById('composer-textarea');
        if (composer) composer.placeholder = `No que voce esta pensando, ${user.nome}? Compartilhe uma duvida, dica ou material...`;
        if (user.email) {
          document.querySelectorAll('.user-email-display').forEach(el => {
            el.textContent = user.email;
          });
        }
        const initials = user.nome.trim().split(/\s+/).slice(0, 2).map(part => part[0]).join('').toUpperCase()
          .replace(/[&<>"']/g, character => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&apos;' })[character]);
        const avatarUrl = typeof user.avatar_url === 'string' && /^https:\/\//i.test(user.avatar_url) && !user.avatar_url.includes('/assets/img/perfil.jpg')
          ? user.avatar_url
          : `data:image/svg+xml,${encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96"><rect width="96" height="96" rx="48" fill="#23366e"/><text x="50%" y="53%" dominant-baseline="middle" text-anchor="middle" font-family="Arial,sans-serif" font-size="34" font-weight="700" fill="#fff">${initials}</text></svg>`)}`;
        document.querySelectorAll('img[src*="/assets/img/perfil.jpg"]').forEach(img => {
          img.src = avatarUrl;
          img.alt = `Avatar de ${user.nome}`;
        });
      }
    })
    .catch(() => {});

  // ─── Notification Dropdown (Simple) ──────────────────────
  const notifBtn = document.getElementById('notif-btn');
  const notifDropdown = document.getElementById('notif-dropdown');
  if (notifBtn && notifDropdown) {
    notifBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      notifDropdown.classList.toggle('hidden');
    });
    document.addEventListener('click', () => {
      notifDropdown.classList.add('hidden');
    });
  }
});

/* ─── Chart.js Theme Helper ─────────────────────────────────
   Call this before creating charts to get theme-aware colors */
function getChartColors() {
  const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
  return {
    grid: isDark ? '#334155' : '#E5E7EB',
    text: isDark ? '#94A3B8' : '#6B7280',
    blue: isDark ? '#60A5FA' : '#23366e',
    green: isDark ? '#34D399' : '#10B981',
    orange: isDark ? '#FBBF24' : '#F59E0B',
    purple: isDark ? '#A78BFA' : '#8B5CF6',
    cyan: isDark ? '#38BDF8' : '#06B6D4',
    grayLine: isDark ? '#475569' : '#D1D5DB',
    bgBlue: isDark ? 'rgba(96, 165, 250, 0.2)' : 'rgba(35, 54, 110, 0.1)',
    bgGreen: isDark ? 'rgba(52, 211, 153, 0.2)' : 'rgba(16, 185, 129, 0.1)',
    pointBg: isDark ? '#1E293B' : '#FFFFFF',
  };
}
