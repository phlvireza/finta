/* ==========================================================================
   Finta site behaviour: theme toggle, scroll reveal, waitlist form.
   No dependencies, no build step.
   ========================================================================== */
(function () {
  'use strict';

  var root = document.documentElement;

  /* ------------------------------------------------------------------
     Theme toggle
     Three states exist: explicit light, explicit dark, and "follow the
     system" (no data-theme attribute at all). The toggle only ever writes
     an explicit value, so a first click has to resolve what the viewer is
     currently *seeing* before flipping it.
     ------------------------------------------------------------------ */
  var toggle = document.getElementById('theme-toggle');

  function currentTheme() {
    var explicit = root.getAttribute('data-theme');
    if (explicit === 'dark' || explicit === 'light') return explicit;
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }

  if (toggle) {
    toggle.addEventListener('click', function () {
      var next = currentTheme() === 'dark' ? 'light' : 'dark';
      root.setAttribute('data-theme', next);
      try { localStorage.setItem('finta-theme', next); } catch (e) {}
    });
  }

  /* ------------------------------------------------------------------
     Mobile menu
     ------------------------------------------------------------------ */
  var navToggle = document.getElementById('nav-toggle');
  var navPanel = document.getElementById('nav-panel');

  if (navToggle && navPanel) {
    var setMenu = function (open) {
      navPanel.classList.toggle('is-open', open);
      navToggle.setAttribute('aria-expanded', String(open));
      navToggle.setAttribute('aria-label', open ? 'Close menu' : 'Open menu');
    };

    navToggle.addEventListener('click', function () {
      setMenu(navToggle.getAttribute('aria-expanded') !== 'true');
    });

    // Tapping a link jumps to a section; leaving the panel covering it would
    // hide the thing the reader just asked for.
    navPanel.addEventListener('click', function (event) {
      if (event.target.closest('a')) setMenu(false);
    });

    document.addEventListener('keydown', function (event) {
      if (event.key !== 'Escape') return;
      if (navToggle.getAttribute('aria-expanded') !== 'true') return;
      setMenu(false);
      navToggle.focus();
    });

    // Widening past the breakpoint hides the toggle; without this the menu
    // would stay "open" and reopen on the way back down.
    var wide = window.matchMedia('(min-width: 860px)');
    var onWide = function (e) { if (e.matches) setMenu(false); };

    // Safari and iOS Safari before 14 expose only the deprecated addListener
    // on MediaQueryList. Calling addEventListener there throws, and because
    // this is the last statement in the nav block, the throw would abort the
    // rest of this file -- taking scroll-reveal and the waitlist submit
    // handler with it. The head script has already removed .no-js by then, so
    // the reveal elements would stay at opacity 0 with nothing left to show
    // them.
    if (wide.addEventListener) wide.addEventListener('change', onWide);
    else if (wide.addListener) wide.addListener(onWide);
  }

  /* ------------------------------------------------------------------
     Scroll reveal. Purely decorative, so anything that goes wrong should
     leave the content visible rather than hidden.
     ------------------------------------------------------------------ */
  var reveals = document.querySelectorAll('.reveal');

  if (!('IntersectionObserver' in window) ||
      window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    Array.prototype.forEach.call(reveals, function (el) { el.classList.add('is-visible'); });
  } else {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        entry.target.classList.add('is-visible');
        io.unobserve(entry.target);
      });
    }, { rootMargin: '0px 0px -8% 0px', threshold: 0.08 });

    Array.prototype.forEach.call(reveals, function (el) { io.observe(el); });
  }

  /* ------------------------------------------------------------------
     Waitlist
     ------------------------------------------------------------------
     THIS DOES NOT COLLECT EMAIL ADDRESSES YET.

     A static site cannot store a submission on its own. Until FORM_ENDPOINT
     points at a real collector (Formspree, Buttondown, a Google Form, a
     serverless function -- anything that accepts a POST), the form validates
     the address, shows the success state, and then throws it away.

     To make it live, set FORM_ENDPOINT to the POST URL. Nothing else needs
     to change: the submit handler already posts JSON and handles failure.
     ------------------------------------------------------------------ */
  var FORM_ENDPOINT = '';

  var EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

  function setStatus(form, state, message) {
    var el = form.querySelector('.form-status');
    if (!el) return;
    el.setAttribute('data-state', state);
    el.textContent = message;
  }

  Array.prototype.forEach.call(document.querySelectorAll('.waitlist'), function (form) {
    form.addEventListener('submit', function (event) {
      event.preventDefault();

      var input = form.querySelector('input[type="email"]');
      var button = form.querySelector('button[type="submit"]');
      var email = (input.value || '').trim();

      if (!EMAIL_RE.test(email)) {
        setStatus(form, 'error', 'That address doesn’t look right — mind checking it?');
        input.focus();
        return;
      }

      // Always restore the button, on every exit path, so a failed request
      // can never leave it stuck reading "Adding you...".
      var originalLabel = button.textContent;
      button.disabled = true;
      button.textContent = 'Adding you…';

      function done(state, message) {
        button.disabled = false;
        button.textContent = originalLabel;
        setStatus(form, state, message);
      }

      function succeed() {
        form.reset();
        done('success', 'You’re on the list. We’ll email once, at launch.');
      }

      if (!FORM_ENDPOINT) {
        // No collector wired up yet -- acknowledge without pretending to store.
        window.setTimeout(succeed, 400);
        return;
      }

      fetch(FORM_ENDPOINT, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
        body: JSON.stringify({ email: email })
      }).then(function (response) {
        if (!response.ok) throw new Error('Request failed: ' + response.status);
        succeed();
      }).catch(function () {
        done('error', 'Something went wrong on our side. Try again in a moment?');
      });
    });
  });
})();
