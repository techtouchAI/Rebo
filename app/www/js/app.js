/* ============================================================
   Rebo · التربية الفنية — application logic
   Vanilla JS, no dependencies, offline-first.
   ============================================================ */
(function () {
  'use strict';

  var C = window.REBO_CONTENT || { units: [], plans: [], index: [], intro: {}, meta: {} };
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };

  /* ---------------- storage ---------------- */
  var MEM = {};
  var store = {
    get: function (k, d) {
      try { var v = localStorage.getItem('rebo:' + k); return v ? JSON.parse(v) : d; }
      catch (e) { return k in MEM ? MEM[k] : d; }
    },
    set: function (k, v) {
      MEM[k] = v;
      try { localStorage.setItem('rebo:' + k, JSON.stringify(v)); } catch (e) {}
    }
  };

  /* ---------------- helpers ---------------- */
  function esc(s) {
    return String(s == null ? '' : s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }
  function rtlNum(n) { return String(n); }
  var AR_DIGITS = '٠١٢٣٤٥٦٧٨٩';
  function arDigit(s) {
    return String(s).replace(/[0-9]/g, function (d) { return AR_DIGITS[+d]; });
  }
  var GRADE_META = {
    'الصف الأول المتوسط': { short: 'الأول', color: 'var(--m-teal)', cls: 'chip-teal' },
    'الصف الثاني المتوسط': { short: 'الثاني', color: 'var(--m-blue)', cls: 'chip-blue' },
    'الصف الثالث المتوسط': { short: 'الثالث', color: 'var(--m-violet)', cls: 'chip-violet' },
    'المرحلة المتوسطة': { short: 'عام', color: 'var(--m-amber)', cls: 'chip-amber' }
  };
  function gmeta(g) { return GRADE_META[g] || { short: 'عام', color: 'var(--m-amber)', cls: 'chip-amber' }; }
  function unitShort(u) {
    var m = /الوحدة\s+(\S+)/.exec(u.unitName || '');
    return m ? 'الوحدة ' + m[1] : (u.unitName || 'وحدة');
  }
  function toast(msg) {
    var t = $('#toast');
    t.textContent = msg;
    t.classList.add('show');
    clearTimeout(toast._t);
    toast._t = setTimeout(function () { t.classList.remove('show'); }, 1900);
  }
  function totalQuestions() {
    return C.units.reduce(function (a, u) { return a + u.mcq.length + u.truefalse.length; }, 0);
  }

  /* ---------------- routing ---------------- */
  var routes = {};
  var current = { name: 'home', params: {} };
  var depth = 0;
  window.ReboNav = {
    canBack: function () { return depth > 0; },
    back: function () { history.back(); },
    version: '1.0.0'
  };
  function go(name, params, opts) {
    params = params || {};
    var arg = params.id || params.grade || '';
    var hash = '#' + name + (arg ? '/' + encodeURIComponent(arg) : '');
    if (opts && opts.replace) history.replaceState(params, '', hash);
    else { history.pushState(params, '', hash); depth++; }
    render(name, params);
  }
  function parseHash() {
    var h = location.hash.replace(/^#\/?/, '');
    if (!h) return { name: 'home', params: {} };
    var i = h.indexOf('/');
    var name = i < 0 ? h : h.slice(0, i);
    var arg = i < 0 ? '' : decodeURIComponent(h.slice(i + 1));
    return { name: name, params: { id: arg, grade: arg } };
  }
  window.addEventListener('hashchange', function () {
    var p = parseHash();
    if (p.name !== current.name || (p.params.id || '') !== (current.params.id || '')) {
      current = p;
      render(p.name, p.params);
    }
  });
  window.addEventListener('popstate', function () {
    depth = Math.max(0, depth - 1);
    var p = parseHash();
    current = p;
    render(p.name, p.params);
  });

  /* ---------------- shell ---------------- */
  var TITLES = {
    home: 'ريبو · التربية الفنية',
    index: 'الفهرس',
    grade: 'الوحدات',
    unit: 'الوحدة',
    plans: 'خطط الدروس',
    plan: 'خطة الدرس',
    quiz: 'اختبر نفسك',
    studio: 'المختبر الفني',
    about: 'عن التطبيق',
    intro: 'المقدمة'
  };
  function setTitle(t) {
    $('#topbarTitle').textContent = t;
    $('#topbarTitle').setAttribute('title', t);
  }
  function setTab(name) {
    $$('.tab').forEach(function (b) {
      b.classList.toggle('active', b.dataset.route === name);
    });
  }

  /* ---------------- views ---------------- */
  /* Decorative hero composition: three nested arcs + a diamond, echoing the
     app mark. Pure SVG, no assets, deterministic. */
  function heroArt() {
    return '<svg class="hero-art" viewBox="0 0 420 420" aria-hidden="true">' +
      '<defs>' +
        '<linearGradient id="ha1" x1="0" y1="0" x2="1" y2="1">' +
          '<stop offset="0" stop-color="#7ad6c0" stop-opacity=".75"/>' +
          '<stop offset="1" stop-color="#7ad6c0" stop-opacity="0"/>' +
        '</linearGradient>' +
        '<linearGradient id="ha2" x1="1" y1="0" x2="0" y2="1">' +
          '<stop offset="0" stop-color="#e8c07d" stop-opacity=".65"/>' +
          '<stop offset="1" stop-color="#e8c07d" stop-opacity="0"/>' +
        '</linearGradient>' +
      '</defs>' +
      '<circle cx="210" cy="210" r="196" fill="none" stroke="url(#ha1)" stroke-width="1.5"/>' +
      '<circle cx="210" cy="210" r="150" fill="none" stroke="rgba(255,255,255,.13)" stroke-width="1.2"/>' +
      '<circle cx="210" cy="210" r="104" fill="none" stroke="url(#ha2)" stroke-width="1.5"/>' +
      '<path d="M210 96 L324 210 L210 324 L96 210 Z" fill="none" stroke="rgba(255,255,255,.22)" stroke-width="1.6"/>' +
      '<path d="M210 140 L280 210 L210 280 L140 210 Z" fill="none" stroke="rgba(122,214,192,.5)" stroke-width="1.4"/>' +
      '<circle cx="210" cy="210" r="7" fill="#e8c07d"/>' +
      '<circle cx="324" cy="210" r="4" fill="#7ad6c0"/>' +
      '<circle cx="96" cy="210" r="4" fill="rgba(255,255,255,.5)"/>' +
      '<circle cx="210" cy="96" r="3" fill="rgba(255,255,255,.4)"/>' +
      '<circle cx="210" cy="324" r="3" fill="rgba(255,255,255,.4)"/>' +
      '</svg>';
  }

  function viewHome() {
    var last = store.get('last', null);
    var lastUnit = last ? C.units.filter(function (u) { return u.id === last.id; })[0] : null;
    var grades = ['الصف الأول المتوسط', 'الصف الثاني المتوسط', 'الصف الثالث المتوسط'];
    var html = '';
    html += '<section class="hero">' + heroArt() + '<div class="hero-in">' +
      '<span class="eyebrow">دليل المعلم · المرحلة المتوسطة</span>' +
      '<h1>التربية الفنية،<br>بروحٍ جديدة.</h1>' +
      '<p>كل وحدات دليل التربية الفنية للمرحلة المتوسطة، بخطةٍ واحدة واضحة: مواضيع، أهداف، أدوات، أسئلة تقويم، ومختبر تفاعلي للألوان والمنظور.</p>' +
      '<div class="hero-actions">' +
        '<button class="btn" data-go="index"><svg viewBox="0 0 24 24"><path d="M5 6h14M5 12h14M5 18h9" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>ابدأ الفهرس</button>' +
        '<button class="btn ghost" data-go="quiz"><svg viewBox="0 0 24 24"><path d="M12 3.5 14.6 9l6 .8-4.4 4.2 1.1 6-5.3-3-5.3 3 1.1-6L3.4 9.8 9.4 9z" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linejoin="round"/></svg>اختبر نفسك</button>' +
      '</div>' +
      '<div class="hero-stats">' +
        '<div><b>' + arDigit(C.units.length) + '</b>وحدة دراسية</div>' +
        '<div><b>' + arDigit(C.plans.length) + '</b>خطة أسبوعية</div>' +
        '<div><b>' + arDigit(totalQuestions()) + '</b>سؤال تقويم</div>' +
        '<div><b>' + arDigit(C.units.reduce(function (a, u) { return a + u.sections.length; }, 0)) + '</b>موضوعًا</div>' +
      '</div>' +
      '</div></section>';

    if (lastUnit) {
      html += '<div class="section-head"><h2>أكمل من حيث توقفت</h2></div>' +
        '<button class="continue-card" data-unit="' + lastUnit.id + '">' +
        '<svg class="ring" viewBox="0 0 40 40"><circle cx="20" cy="20" r="16" fill="none" stroke="rgba(255,255,255,.15)" stroke-width="3"/>' +
        '<circle cx="20" cy="20" r="16" fill="none" stroke="var(--m-teal)" stroke-width="3" stroke-linecap="round" stroke-dasharray="' + (100 * (last.pct || 5) / 100).toFixed(1) + ' 100" pathLength="100" transform="rotate(-90 20 20)"/></svg>' +
        '<div style="flex:1"><h3>' + esc(lastUnit.title.replace(/^الصف \S+ المتوسط - /, '')) + '</h3>' +
        '<p>' + esc(gmeta(lastUnit.grade).short) + ' المتوسط · ' + arDigit(lastUnit.sections.length) + ' مواضيع · تقدمك ' + arDigit(Math.round(last.pct || 0)) + '٪</p></div>' +
        '<span class="pill chip-teal">متابعة</span></button>';
    }

    html += '<div class="section-head"><h2>الصفوف</h2><span class="link" data-go="index">كل الوحدات ←</span></div><div class="grade-row">';
    grades.forEach(function (g, i) {
      var units = C.units.filter(function (u) { return u.grade === g; });
      var m = gmeta(g);
      html += '<button class="grade-card" data-grade="' + esc(g) + '">' +
        '<span class="g-num">' + arDigit(i + 1) + '</span>' +
        '<span class="pill ' + m.cls + '">الصف ' + m.short + '</span>' +
        '<h3 style="margin-top:10px">' + esc(g.replace('الصف ', '')) + '</h3>' +
        '<p>' + arDigit(units.length) + ' وحدات · ' + arDigit(units.reduce(function (a, u) { return a + u.sections.length; }, 0)) + ' موضوعًا</p>' +
        '<div class="g-line">' + units.map(function (u) {
          return '<i style="background:' + (u.grade === 'الصف الأول المتوسط' ? 'rgba(87,195,167,.55)' : u.grade === 'الصف الثاني المتوسط' ? 'rgba(111,140,255,.55)' : 'rgba(169,124,240,.55)') + '"></i>';
        }).join('') + '</div></button>';
    });
    html += '</div>';

    html += '<div class="section-head"><h2>اكتشف بالممارسة</h2></div><div class="grade-row">' +
      '<button class="grade-card" data-go="studio">' +
        '<span class="pill chip-amber">تفاعلي</span><h3 style="margin-top:10px">مختبر الألوان</h3>' +
        '<p>امزج الألوان الأساسية وشاهد الألوان الثانوية والثلاثية فورًا.</p></button>' +
      '<button class="grade-card" data-go="studio">' +
        '<span class="pill chip-blue">تفاعلي</span><h3 style="margin-top:10px">مخبر المنظور</h3>' +
        '<p>حرّك خط الأفق ونقطة التلاشي لتفهم العمق على سطح مسطّح.</p></button>' +
      '<button class="grade-card" data-go="quiz">' +
        '<span class="pill chip-teal">تقويم</span><h3 style="margin-top:10px">بنك الأسئلة</h3>' +
        '<p>' + arDigit(totalQuestions()) + ' سؤالًا من أسئلة تقويم الوحدات، بتصحيح فوري.</p></button>' +
      '</div>';

    html += '<div class="section-head"><h2>من الدليل</h2><span class="link" data-go="intro">المقدمة ←</span></div>' +
      '<div class="obj-grid">' +
      C.plans.slice(0, 2).map(function (p) {
        return '<button class="continue-card" data-plan="' + esc(p.name) + '">' +
          '<span class="pill chip-amber">خطة أسبوعية</span>' +
          '<div style="flex:1"><h3>' + esc(p.title) + '</h3><p>' + esc(p.grade) + ' · ' + esc(p.kind || '') + '</p></div>' +
          '<span class="u-go">‹</span></button>';
      }).join('') + '</div>';

    html += '<div class="section-head"><h2>وحدات سريعة الوصول</h2></div>';
    html += C.units.slice(0, 4).map(unitCard).join('');
    return html;
  }

  function unitCard(u) {
    var m = gmeta(u.grade);
    return '<button class="unit-card" data-unit="' + u.id + '" style="margin-bottom:8px">' +
      '<span class="u-idx" style="color:' + m.color + '">' + arDigit(u.id) + '</span>' +
      '<span><h3>' + esc(u.title.replace(/^الصف \S+ المتوسط - /, '')) + '</h3>' +
      '<p>' + esc(u.grade) + ' · ' + arDigit(u.sections.length) + ' مواضيع · ' + arDigit(u.mcq.length + u.truefalse.length) + ' سؤالًا</p></span>' +
      '<span class="u-go">‹</span></button>';
  }

  function viewIndex() {
    var grades = ['الكل', 'الصف الأول المتوسط', 'الصف الثاني المتوسط', 'الصف الثالث المتوسط', 'المرحلة المتوسطة'];
    var active = store.get('indexFilter', 'الكل');
    var html = '<span class="eyebrow">فهرس المحتوى</span><h2 style="font-size:22px;margin:8px 0 4px">كل ما في الدليل، مرتّبًا.</h2>' +
      '<p style="font-size:13px;color:var(--text-mute);margin-bottom:16px">' + arDigit(C.units.length) + ' وحدة و' + arDigit(C.plans.length) + ' خطة درس، مقسّمة حسب الصف والوحدة.</p>';
    html += '<div class="filter-bar">' + grades.map(function (g) {
      return '<button class="fbtn' + (g === active ? ' active' : '') + '" data-filter="' + esc(g) + '">' + esc(g === 'الكل' ? 'كل الصفوف' : g.replace('الصف ', '').replace(' المتوسط', ' متوسط')) + '</button>';
    }).join('') + '</div>';
    html += '<div class="toc-list">';
    C.units.forEach(function (u) {
      if (active !== 'الكل' && u.grade !== active) return;
      var m = gmeta(u.grade);
      html += '<button class="toc-row" data-unit="' + u.id + '">' +
        '<span class="n">' + arDigit(u.id) + '</span>' +
        '<span><span class="t">' + esc(u.title.replace(/^الصف \S+ المتوسط - /, '')) + '</span><br>' +
        '<span class="m">' + esc(u.grade) + ' · ' + esc(unitShort(u)) + ' · ' + arDigit(u.sections.length) + ' مواضيع</span></span>' +
        '<span class="pill ' + m.cls + '">ص ' + arDigit(u.pages || '') + '</span></button>';
    });
    html += '</div>';
    html += '<div class="section-head"><h2>خطط الدروس الأسبوعية</h2></div><div class="toc-list">';
    C.plans.forEach(function (p) {
      html += '<button class="toc-row" data-plan="' + esc(p.name) + '"><span class="n">◇</span>' +
        '<span><span class="t">' + esc(p.title) + '</span><br><span class="m">' + esc(p.grade) + ' · ' + esc(p.kind || 'خطة') + '</span></span>' +
        '<span class="pill chip-amber">خطة</span></button>';
    });
    html += '</div>';
    return html;
  }

  function viewGrade(params) {
    var g = params.grade || 'الصف الأول المتوسط';
    var units = C.units.filter(function (u) { return u.grade === g; });
    var m = gmeta(g);
    var html = '<span class="pill ' + m.cls + '">' + esc(g) + '</span>' +
      '<h2 style="font-size:22px;margin:12px 0 4px">وحدات الصف ' + esc(m.short) + '</h2>' +
      '<p style="font-size:13px;color:var(--text-mute);margin-bottom:18px">اختر وحدة للبدء بالقراءة.</p>';
    html += units.map(function (u) {
      return '<button class="unit-card" data-unit="' + u.id + '" style="margin-bottom:9px">' +
        '<span class="u-idx">' + arDigit(u.id) + '</span><span><h3>' + esc(u.title.replace(/^الصف \S+ المتوسط - /, '')) + '</h3>' +
        '<p>' + arDigit(u.sections.length) + ' مواضيع · صفحات الدليل ' + arDigit(u.pages || '—') + '</p></span>' +
        '<span class="u-go">‹</span></button>';
    }).join('');
    return html;
  }

  function viewUnit(params) {
    var u = C.units.filter(function (x) { return x.id === params.id; })[0];
    if (!u) return '<div class="empty">الوحدة غير موجودة.</div>';
    var m = gmeta(u.grade);
    var bold = store.get('serif', false), large = store.get('large', false);
    document.body.classList.toggle('serif', !!bold);
    document.body.classList.toggle('large', !!large);

    var html = '<div class="unit-hero uh-plain" data-tint="' + (u.grade || '') + '">' +
      '<div class="uh-grad"></div><div class="uh-body">' +
      '<span class="pill ' + m.cls + '">' + esc(u.grade) + '</span>' +
      '<h1 style="margin-top:8px">' + esc(u.title.replace(/^الصف \S+ المتوسط - /, '')) + '</h1>' +
      '<div class="unit-meta"><span class="pill">صفحات الدليل ' + arDigit(u.pages || '—') + '</span>' +
      '<span class="pill">' + arDigit(u.sections.length) + ' مواضيع</span>' +
      '<span class="pill">' + arDigit(u.mcq.length + u.truefalse.length) + ' سؤال تقويم</span></div>' +
      '</div></div>';

    html += '<div class="reader-tools">' +
      '<button class="tool-btn' + (bold ? ' active' : '') + '" data-toggle="serif">خط الأميري</button>' +
      '<button class="tool-btn' + (large ? ' active' : '') + '" data-toggle="large">تكبير الخط</button>' +
      '<span class="spacer"></span>' +
      '<button class="tool-btn" data-toc="1">فهرس الوحدة</button></div>';

    html += '<div class="obj-grid">' +
      (u.objectives ? '<div class="obj-card"><h4>الأهداف العامة</h4><p>' + esc(u.objectives) + '</p></div>' : '') +
      (u.specific && u.specific.length ? '<div class="obj-card"><h4>الأهداف الخاصة</h4><ul>' +
        u.specific.map(function (s) { return '<li>' + esc(s) + '</li>'; }).join('') + '</ul></div>' : '') +
      (u.tools ? '<div class="obj-card"><h4>الوسائل التعليمية</h4><p>' + esc(u.tools.replace(/^[^:：]*[:：]\s*/, '')) + '</p></div>' : '') +
      (u.intro ? '<div class="obj-card"><h4>التهيئة المقترحة</h4><p>' + esc(u.intro) + '</p></div>' : '') +
      '</div>';

    /* ---- visual gallery: plates from the teacher's guide + generative plates */
    var plates = (u.plates || []);
    var visuals = [{ type: 'gen', unit: u }].concat(plates.map(function (f) {
      return { type: 'plate', src: 'media/' + f };
    }));
    html += '<div class="section-head"><h2>لوحات وصفحات من الدليل</h2>' +
      '<button class="link" data-gallery="' + u.id + '">عرض كامل ←</button></div>';
    html += '<div class="gallery">' + visuals.map(function (v, i) {
      if (v.type === 'plate') {
        return '<button class="g-item plate" data-gallery="' + u.id + '" data-gi="' + i + '">' +
          '<img src="' + v.src + '" alt="لوحة من دليل المعلم" loading="lazy" decoding="async">' +
          '<span class="g-tag">من الدليل</span></button>';
      }
      return '<button class="g-item gen" data-gallery="' + u.id + '" data-gi="' + i + '">' +
        artSVG(u, true) + '<span class="g-tag">لوحة توليدية</span></button>';
    }).join('') + '</div>';

    /* table of contents of the unit */
    if (u.sections.length > 1) {
      html += '<div class="section-head"><h2>مواضيع الوحدة</h2><span class="link" data-toc="1">انتقال سريع</span></div>' +
        '<div class="toc-list">' + u.sections.map(function (s, i) {
          return '<button class="toc-row" data-sec="sec-' + i + '"><span class="n">' + arDigit(i + 1) + '</span>' +
            '<span class="t">' + esc(shorten(s.title, 78)) + '</span><span class="m">' + arDigit((s.paras || []).length) + ' فقرة</span></button>';
        }).join('') + '</div>';
    }

    html += '<div class="section-head"><h2>شرح الموضوعات</h2></div>';
    u.sections.forEach(function (s, i) {
      html += '<article class="sec" id="sec-' + i + '"><div class="sec-head"><span class="sec-num">' + arDigit(i + 1) + '</span><h3>' + esc(s.title) + '</h3></div>' +
        (s.paras || []).map(function (p) { return '<p>' + esc(p) + '</p>'; }).join('') + '</article>';
    });

    if (u.summary && u.summary.length) {
      html += '<div class="section-head"><h2>خلاصة الدرس</h2></div><div class="obj-card"><ul>' +
        u.summary.map(function (s) { return '<li>' + esc(s) + '</li>'; }).join('') + '</ul></div>';
    }

    var qs = u.mcq.length + u.truefalse.length;
    if (qs) {
      html += '<div class="section-head"><h2>أسئلة التقويم</h2><span class="link" data-quiz="' + u.id + '">ابدأ الاختبار ←</span></div>' +
        '<div class="score-pill"><b>' + arDigit(qs) + '</b><span>سؤالًا في هذه الوحدة — اختيار من متعدد وصح/خطأ، مع التصحيح الفوري وشرح الإجابة.</span></div>' +
        '<div style="margin-top:10px"><button class="btn" data-quiz="' + u.id + '">ابدأ التقويم</button></div>';
    }

    var idx = C.units.indexOf(u);
    var prev = C.units[idx - 1], next = C.units[idx + 1];
    html += '<div class="reader-nav">' +
      (prev ? '<button class="btn ghost" data-unit="' + prev.id + '">→ ' + esc(shorten(prev.title.replace(/^الصف \S+ المتوسط - /, ''), 34)) + '</button>' : '') +
      (next ? '<button class="btn" data-unit="' + next.id + '">' + esc(shorten(next.title.replace(/^الصف \S+ المتوسط - /, ''), 34)) + ' ←</button>' : '') +
      '</div>';

    setTimeout(function () { trackProgress(u); }, 400);
    return html;
  }

  function shorten(s, n) { return s.length > n ? s.slice(0, n - 1) + '…' : s; }

  function trackProgress(u) {
    var view = $('#view');
    var last = store.get('last', {});
    store.set('last', { id: u.id, pct: Math.max(4, last.id === u.id ? (last.pct || 4) : 4) });
    var onScroll = function () {
      var total = view.scrollHeight - window.innerHeight;
      var pct = total > 0 ? Math.min(100, Math.round(window.scrollY / total * 100)) : 100;
      $('#readProgress').style.width = pct + '%';
      if (pct % 10 === 0 && pct > 0) store.set('last', { id: u.id, pct: pct });
    };
    window.removeEventListener('scroll', window.__reboScroll || function () {});
    window.__reboScroll = onScroll;
    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();
  }

  function viewPlans() {
    var html = '<span class="eyebrow">الخطة الأسبوعية</span>' +
      '<h2 style="font-size:22px;margin:8px 0 4px">خطط دروس جاهزة للتنفيذ</h2>' +
      '<p style="font-size:13px;color:var(--text-mute);margin-bottom:18px">لكل خطة: الموضوع، الأهداف العامة والخاصة، الوسائل، المقدمة، والعرض.</p>';
    html += '<div class="plan-grid">' + C.plans.map(function (p) {
      return '<button class="plan-card" data-plan="' + esc(p.name) + '">' +
        '<span class="pill ' + (p.kind === 'عملي' ? 'chip-blue' : p.kind === 'تهيئة' ? 'chip-amber' : 'chip-teal') + '">' + esc(p.kind || 'خطة') + '</span>' +
        '<h3>' + esc(p.title) + '</h3><p>' + esc(p.grade) + ' · ' + arDigit((p.specific || []).length) + ' هدفًا خاصًا</p></button>';
    }).join('') + '</div>';

    html += '<div class="section-head"><h2>المقدمة وأهداف المادة</h2><span class="link" data-go="intro">قراءة كاملة ←</span></div>' +
      '<div class="toc-list"><button class="toc-row" data-go="intro"><span class="n">※</span>' +
      '<span><span class="t">المقدمة، طرائق التدريس، وأهداف التربية الفنية</span><br>' +
      '<span class="m">من دليل المعلم — صفحات 3–13</span></span><span class="pill chip-amber">دليل</span></button></div>';
    return html;
  }

  function viewPlan(params) {
    var p = C.plans.filter(function (x) { return x.name === params.id; })[0];
    if (!p) return '<div class="empty">الخطة غير موجودة.</div>';
    var html = '<div class="unit-hero uh-plain plan-hero">' +
      '<div class="uh-grad"></div><div class="uh-body">' +
      '<span class="pill chip-teal">خطة أسبوعية · ' + esc(p.kind || '') + '</span>' +
      '<h1 style="margin-top:8px">' + esc(p.title) + '</h1>' +
      '<div class="unit-meta"><span class="pill">' + esc(p.grade) + '</span>' +
      '<span class="pill">' + arDigit((p.specific || []).length) + ' هدفًا خاصًا</span>' +
      '<span class="pill">مادة التربية الفنية</span></div>' +
      '</div></div>';

    html += '<div class="reader-tools">' +
      '<button class="tool-btn" data-toggle="serif">خط الأميري</button>' +
      '<button class="tool-btn" data-toggle="large">تكبير الخط</button>' +
      '<span class="spacer"></span>' +
      '<button class="tool-btn" data-go="plans">كل الخطط</button></div>';

    html += '<div class="kv-grid" style="margin-top:16px">' +
      (p.objectives ? '<dl class="kv"><dt>الأهداف العامة</dt><dd>' + esc(p.objectives) + '</dd></dl>' : '') +
      (p.tools && p.tools.length ? '<dl class="kv"><dt>الوسائل التعليمية</dt><dd>' + esc(p.tools.join(' · ')) + '</dd></dl>' : '') +
      '</div>';

    if (p.specific && p.specific.length) {
      html += '<div class="section-head"><h2>الأهداف الخاصة</h2></div><ol class="steps">' +
        p.specific.map(function (s) { return '<li>' + esc(s) + '</li>'; }).join('') + '</ol>';
    }
    if (p.intro) {
      html += '<div class="section-head"><h2>المقدمة / التهيئة</h2></div><article class="sec"><p>' + esc(p.intro) + '</p></article>';
    }
    if (p.present) {
      var chunks = splitSentences(p.present, 520);
      html += '<div class="section-head"><h2>العرض</h2></div><article class="sec">' +
        chunks.map(function (c) { return '<p>' + esc(c) + '</p>'; }).join('') + '</article>';
    }
    html += '<div class="reader-nav" style="margin-top:22px"><button class="btn ghost" data-go="plans">→ كل الخطط</button></div>';
    return html;
  }

  function splitSentences(t, max) {
    var parts = t.split(/(?<=[.؟!])\s+/);
    var out = [], buf = '';
    parts.forEach(function (s) {
      if (buf && (buf + ' ' + s).length > max) { out.push(buf); buf = s; }
      else buf = (buf ? buf + ' ' : '') + s;
    });
    if (buf) out.push(buf);
    return out;
  }

  function viewIntro() {
    var I = C.intro || { sections: [] };
    var html = '<span class="eyebrow">من دليل المعلم</span><h2 style="font-size:22px;margin:8px 0 16px">المقدمة وطرائق التدريس</h2>';
    (I.sections || []).forEach(function (s, i) {
      html += '<article class="sec"><div class="sec-head"><span class="sec-num">' + arDigit(i + 1) + '</span><h3>' + esc(s.title) + '</h3></div>' +
        (s.paras || []).map(function (p) { return '<p>' + esc(p).replace(/\n/g, '<br>') + '</p>'; }).join('') + '</article>';
    });
    if (I.maps && I.maps.length) {
      html += '<div class="section-head"><h2>خريطة الوحدات</h2></div>';
      I.maps.forEach(function (m) {
        html += '<div class="obj-card" style="margin-bottom:10px"><h4>الصف ' + esc(m.grade) + '</h4>' +
          '<div class="kv-grid">' + m.units.map(function (u) {
            return '<div class="kv"><dt>' + esc(u.name) + '</dt><dd>' +
              (u.items.length ? u.items.map(esc).join(' · ') : 'تعبير وتذوق فني') + '</dd></div>';
          }).join('') + '</div></div>';
      });
    }
    return html;
  }

  /* ---------------- quiz ---------------- */
  function buildQuizPool(unitId) {
    var pool = [];
    C.units.forEach(function (u) {
      if (unitId && u.id !== unitId) return;
      u.mcq.forEach(function (q) {
        if (!q.options || q.options.length < 2) return;
        pool.push({
          type: 'mcq', unit: u,
          q: q.q,
          options: q.options.slice(0, 3),
          answer: q.answer && 'أبج'.indexOf(q.answer) >= 0 ? 'أبج'.indexOf(q.answer) : null
        });
      });
      u.truefalse.forEach(function (q) {
        pool.push({
          type: 'tf', unit: u,
          q: q.q.replace(/\(\s*\)\s*$/, '').trim(),
          options: ['صح', 'خطأ'],
          answer: q.answer === 'صح' ? 0 : q.answer === 'خطأ' ? 1 : null
        });
      });
    });
    return pool;
  }

  var quizState = null;
  function newQuiz(unitId) {
    var pool = buildQuizPool(unitId).filter(function (q) { return q.answer != null; });
    for (var i = pool.length - 1; i > 0; i--) {
      var j = Math.floor(Math.random() * (i + 1)); var t = pool[i]; pool[i] = pool[j]; pool[j] = t;
    }
    quizState = { pool: pool.slice(0, 10), i: 0, score: 0, answered: false, unitId: unitId || null, log: [] };
  }

  function viewQuiz(params) {
    if (!quizState || (params.id && quizState.unitId !== params.id) || (!params.id && quizState.unitId)) {
      newQuiz(params.id || null);
    }
    if (!quizState.pool.length) {
      return '<div class="empty">لا توجد أسئلة متاحة لهذه الوحدة.</div>';
    }
    var s = quizState;
    var q = s.pool[s.i];
    var html = '<span class="eyebrow">بنك الأسئلة</span>' +
      '<h2 style="font-size:22px;margin:8px 0 4px">' + (s.unitId ? 'تقويم الوحدة' : 'اختبر نفسك') + '</h2>' +
      '<p style="font-size:13px;color:var(--text-mute);margin-bottom:16px">' +
      (s.unitId ? esc(q.unit.title.replace(/^الصف \S+ المتوسط - /, '')) : 'أسئلة مختارة من كل وحدات المرحلة المتوسطة') +
      ' · ' + arDigit(s.i + 1) + ' من ' + arDigit(s.pool.length) + '</p>';

    html += '<div class="score-pill" style="margin-bottom:14px">' +
      '<b>' + arDigit(s.score) + '</b><span>نقاط صحيحة</span>' +
      '<span class="spacer"></span>' +
      '<span class="pill">' + esc(gmeta(q.unit.grade).short) + ' متوسط</span></div>';

    html += '<div class="q-card"><div class="q-top"><span class="pill ' + gmeta(q.unit.grade).cls + '">' +
      (q.type === 'tf' ? 'صح / خطأ' : 'اختيار من متعدد') + '</span>' +
      '<span class="pill">' + arDigit(s.i + 1) + '/' + arDigit(s.pool.length) + '</span></div>' +
      '<div class="q-text">' + esc(q.q) + '</div><div class="opts">';
    var letters = ['أ', 'ب', 'ج'];
    q.options.forEach(function (o, i) {
      var cls = 'opt';
      var disabled = s.answered ? ' disabled' : '';
      if (s.answered) {
        if (i === q.answer) cls += ' correct';
        else if (s.log[s.i] === i) cls += ' wrong';
      }
      html += '<button class="' + cls + '" data-ans="' + i + '"' + disabled + '>' +
        '<span class="ltr">' + (q.type === 'tf' ? (i === 0 ? '✓' : '✕') : letters[i] || (i + 1)) + '</span>' +
        '<span>' + esc(o) + '</span></button>';
    });
    html += '</div>';
    if (s.answered) {
      html += '<div style="margin-top:14px" class="pull">' +
        (s.log[s.i] === q.answer ? '✔ إجابة صحيحة. أحسنت!' : '✕ الإجابة الصحيحة: ' + esc(q.options[q.answer])) +
        '</div><div style="margin-top:12px"><button class="btn" data-next="1">' +
        (s.i + 1 < s.pool.length ? 'السؤال التالي ←' : 'عرض النتيجة ←') + '</button></div>';
    }
    html += '</div>';

    if (s.i + 1 >= s.pool.length && s.answered) { /* results handled by next */ }
    return html;
  }

  function viewResult() {
    var s = quizState;
    var pct = Math.round(s.score / s.pool.length * 100);
    var msg = pct >= 80 ? 'ممتاز! فهمك للوحدة راسخ.' : pct >= 50 ? 'جيد، ويمكنك التحسّن بمراجعة المواضيع.' : 'راجع الوحدة ثم أعد الاختبار.';
    var html = '<div class="hero" style="text-align:center"><div class="hero-in">' +
      '<span class="eyebrow">نتيجة التقويم</span>' +
      '<h1 style="font-size:52px;margin:12px 0 2px">' + arDigit(s.score) + '<span style="font-size:22px;opacity:.6">/' + arDigit(s.pool.length) + '</span></h1>' +
      '<p style="margin:0 auto">' + esc(msg) + '</p>' +
      '<div class="hero-actions" style="justify-content:center">' +
      '<button class="btn" data-retry="1">إعادة الاختبار</button>' +
      (s.unitId ? '<button class="btn ghost" data-unit="' + s.unitId + '">مراجعة الوحدة</button>' : '<button class="btn ghost" data-go="index">الفهرس</button>') +
      '</div></div></div>';
    html += '<div class="section-head"><h2>مراجعة الأسئلة</h2></div><div class="quiz-shell">';
    s.pool.forEach(function (q, i) {
      var ok = s.log[i] === q.answer;
      html += '<div class="q-card"><div class="q-top"><span class="pill ' + (ok ? 'chip-teal' : 'chip-red') + '">' +
        (ok ? 'صحيحة' : 'خاطئة') + '</span><span class="pill">' + arDigit(i + 1) + '</span></div>' +
        '<div class="q-text" style="margin-bottom:8px">' + esc(q.q) + '</div>' +
        '<p style="font-size:12.5px;color:var(--text-dim)">الإجابة الصحيحة: <b>' + esc(q.options[q.answer]) + '</b></p></div>';
    });
    html += '</div>';
    return html;
  }

  /* ---------------- studio ---------------- */
  var COLOR_NAMES = [
    { n: 'أصفر', hex: '#f2c94c', base: true },
    { n: 'أحمر', hex: '#e0574b', base: true },
    { n: 'أزرق', hex: '#3d6cf0', base: true },
    { n: 'أبيض', hex: '#f4f4f0' },
    { n: 'أسود', hex: '#15161a' }
  ];
  function mixColors(a, b) {
    function hex2rgb(h) { return [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)]; }
    var x = hex2rgb(a), y = hex2rgb(b);
    var r = Math.round((x[0] + y[0]) / 2), g = Math.round((x[1] + y[1]) / 2), bl = Math.round((x[2] + y[2]) / 2);
    function toHex(v) { return ('0' + v.toString(16)).slice(-2); }
    return '#' + toHex(r) + toHex(g) + toHex(bl);
  }
  var labState = store.get('lab', { a: 0, b: 2 });

  function viewStudio() {
    var html = '<span class="eyebrow">المختبر الفني</span>' +
      '<h2 style="font-size:22px;margin:8px 0 4px">جرّب، امزج، ولاحظ.</h2>' +
      '<p style="font-size:13px;color:var(--text-mute);margin-bottom:16px">مختبران تفاعليان يشرحان فكرتين أساسيتين في الدليل: مزج الألوان، والمنظور.</p>';

    html += '<div class="lab">' +
      '<div class="card"><div style="padding:18px">' +
        '<div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:14px">' +
        '<h3 style="font-size:16px">مختبر الألوان</h3><span class="pill chip-amber">مزج صباغي</span></div>' +
        '<div class="mix-pickers">' +
          '<div><span class="eyebrow">اللون الأول</span><div class="swatches" id="swA"></div></div>' +
          '<div><span class="eyebrow">اللون الثاني</span><div class="swatches" id="swB"></div></div>' +
        '</div>' +
        '<div class="mix-stage" style="margin-top:16px">' +
          '<div class="mix-dots"><div class="mix-dot a" id="dotA"></div><div class="mix-dot b" id="dotB"></div></div>' +
          '<div class="mix-result" id="mixResult">—</div>' +
          '<div class="mix-note" id="mixNote"></div>' +
        '</div>' +
      '</div></div>' +
      '<div class="card"><div style="padding:18px">' +
        '<div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:14px">' +
        '<h3 style="font-size:16px">مخبر المنظور</h3><span class="pill chip-blue">عمق على سطح</span></div>' +
        '<div class="persp" id="persp">' +
          '<div class="horizon" id="horizon"></div><div class="vp" id="vp"></div>' +
          '<svg id="perspSvg" viewBox="0 0 400 230" preserveAspectRatio="none"></svg>' +
          '<span class="lbl" style="top:8px;right:10px">خط الأفق</span>' +
          '<span class="lbl" id="vpLbl" style="transform:translate(-50%,-140%)">نقطة التلاشي</span>' +
        '</div>' +
        '<div class="persp-slider"><span>خط الأفق</span><input type="range" min="25" max="80" value="55" id="hzRange"></div>' +
        '<div class="persp-slider"><span>نقطة التلاشي</span><input type="range" min="10" max="90" value="50" id="vpRange"></div>' +
        '<p style="font-size:12px;color:var(--text-mute);margin-top:10px;line-height:1.9">كل الخطوط المستقيمة (الطريق، أعمدة الكهرباء، حدود البناية) تتقارب نحو نقطة التلاشي الواقعة على خط الأفق — وهذا أساس إظهار البعد الثالث في اللوحة.</p>' +
      '</div></div>' +
      '</div>';

    html += '<div class="section-head"><h2>معلومات من الدليل</h2></div><div class="tools-lab">' +
      '<div class="tool-tile"><b>الألوان الأساسية</b><span>الأصفر، الأزرق، الأحمر — لا تُستخرج من مزج ألوان أخرى.</span></div>' +
      '<div class="tool-tile"><b>الألوان الثانوية</b><span>الأخضر، البرتقالي، البنفسجي — من مزج لونين أساسيين.</span></div>' +
      '<div class="tool-tile"><b>الحيادية المطلقة</b><span>الأبيض، الرمادي، الأسود.</span></div>' +
      '<div class="tool-tile"><b>خواص اللون</b><span>كنه اللون، القيمة أو الدرجة، الشدة.</span></div>' +
      '<div class="tool-tile"><b>خط الأرض</b><span>الخط الذي تستند إليه الأشجار والأبنية والأشخاص.</span></div>' +
      '<div class="tool-tile"><b>خطوط التلاشي</b><span>تُرسم من نهاية الشكل وأعلاه وتنتهي عند نقطة التلاشي.</span></div>' +
      '</div>';
    setTimeout(setupLab, 30);
    return html;
  }

  function setupLab() {
    var swA = $('#swA'), swB = $('#swB');
    if (!swA) return;
    function paint(host) {
      host.innerHTML = COLOR_NAMES.map(function (c, i) {
        var sel = (host.id === 'swA' ? labState.a : labState.b) === i ? ' sel' : '';
        return '<button class="swatch' + sel + '" data-sw="' + i + '" style="background:' + c.hex + '" title="' + c.n + '">' +
          '<span>' + c.n + '</span></button>';
      }).join('');
    }
    paint(swA); paint(swB);
    function update() {
      var a = COLOR_NAMES[labState.a], b = COLOR_NAMES[labState.b];
      $('#dotA').style.background = a.hex;
      $('#dotB').style.background = b.hex;
      var mixed = mixColors(a.hex, b.hex);
      var res = $('#mixResult');
      res.style.background = mixed;
      res.textContent = a.n + ' + ' + b.n;
      res.style.color = (labState.a === 3 && labState.b === 3) ? '#333' : (mixed === '#15161a' ? '#fff' : '#11151c');
      $('#mixNote').textContent = describeMix(a, b, mixed);
      store.set('lab', labState);
    }
    function pick(which, i) {
      if (which === 'a') labState.a = i; else labState.b = i;
      paint(swA); paint(swB); update();
    }
    swA.addEventListener('click', function (e) {
      var t = e.target.closest('[data-sw]'); if (t) pick('a', +t.dataset.sw);
    });
    swB.addEventListener('click', function (e) {
      var t = e.target.closest('[data-sw]'); if (t) pick('b', +t.dataset.sw);
    });
    update();

    /* perspective */
    var persp = $('#persp'), horizon = $('#horizon'), vp = $('#vp'), svg = $('#perspSvg');
    if (!persp) return;
    function draw() {
      var hz = +$('#hzRange').value, vpx = +$('#vpRange').value;
      horizon.style.top = hz + '%';
      vp.style.top = hz + '%';
      vp.style.left = vpx + '%';
      $('#vpLbl').style.top = hz + '%';
      $('#vpLbl').style.left = vpx + '%';
      var y = hz * 2.3, x = vpx * 4;
      var lines = [];
      var cols = [0, 60, 130, 200, 270, 340, 400];
      cols.forEach(function (cx) {
        lines.push('<line x1="' + x + '" y1="' + y + '" x2="' + cx + '" y2="230" stroke="rgba(255,255,255,.34)" stroke-width="1.4"/>');
        lines.push('<line x1="' + x + '" y1="' + y + '" x2="' + cx + '" y2="0" stroke="rgba(255,255,255,.12)" stroke-width="1"/>');
      });
      lines.push('<line x1="0" y1="' + y + '" x2="400" y2="' + y + '" stroke="rgba(255,255,255,.5)" stroke-width="1.2" stroke-dasharray="6 5"/>');
      /* receding poles: height shrinks with distance */
      var poles = [];
      [-90, -40, 0, 45, 90].forEach(function (dx, i) {
        var t = (i + 1) / 7;
        var px = x + dx, py = y + (230 - y) * (0.22 + t * 0.7);
        var hgt = 60 * (1 - t * 0.72);
        if (py < 232) {
          poles.push('<line x1="' + px + '" y1="' + py + '" x2="' + px + '" y2="' + (py - hgt) + '" stroke="rgba(232,180,74,.75)" stroke-width="2.4" stroke-linecap="round"/>');
          poles.push('<circle cx="' + px + '" cy="' + (py - hgt) + '" r="2.4" fill="rgba(232,180,74,.9)"/>');
        }
      });
      svg.innerHTML = lines.join('') + poles.join('');
    }
    $('#hzRange').addEventListener('input', draw);
    $('#vpRange').addEventListener('input', draw);
    draw();
  }

  function describeMix(a, b, mixed) {
    var names = [a.n, b.n].sort().join('+');
    var map = {
      'أحمر+أصفر': 'برتقالي — لون ثانوي ناتج من مزج لونين أساسيين.',
      'أزرق+أصفر': 'أخضر — لون ثانوي ناتج من مزج لونين أساسيين.',
      'أحمر+أزرق': 'بنفسجي — لون ثانوي ناتج من مزج لونين أساسيين.',
      'أزرق+أبيض': 'درجة فاتحة من الأزرق — تغيّر في القيمة (الدرجة) لا في كنه اللون.',
      'أبيض+أحمر': 'درجة وردية — تغيّر في القيمة (الدرجة) لا في كنه اللون.',
      'أبيض+أصفر': 'درجة فاتحة من الأصفر — تغيّر في الدرجة لا في الكنه.',
      'أسود+أحمر': 'درجة غامقة من الأحمر — تغيّر في القيمة.',
      'أسود+أزرق': 'درجة غامقة من الأزرق — تغيّر في القيمة.',
      'أسود+أصفر': 'درجة غامقة من الأصفر — تغيّر في القيمة.',
      'أبيض+أسود': 'رمادي — من الألوان الحيادية المطلقة.'
    };
    if (a.n === b.n) return 'اختر لونين مختلفين لمشاهدة نتيجة المزج.';
    return map[names] || 'مزج لونين أساسيين ينتج لونًا ثانويًا، ومزج الأساسي مع الثانوي ينتج لونًا ثلاثيًا.';
  }


  /* ---------------- generative artwork (SVG) ---------------- */
  var PALETTES = {
    'الصف الأول المتوسط': ['#e8654a', '#e8b44a', '#57c3a7', '#2b3a52'],
    'الصف الثاني المتوسط': ['#6f8cff', '#57c3a7', '#e8b44a', '#20283c'],
    'الصف الثالث المتوسط': ['#a97cf0', '#e8654a', '#e8b44a', '#221b33'],
    'المرحلة المتوسطة': ['#e8b44a', '#e8654a', '#57c3a7', '#2a2f3c']
  };
  function seedFrom(str) {
    var h = 2166136261;
    for (var i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = Math.imul(h, 16777619); }
    return h >>> 0;
  }
  function rng(seed) {
    var s = seed || 1;
    return function () { s ^= s << 13; s ^= s >>> 17; s ^= s << 5; s >>>= 0; return s / 4294967296; };
  }
  /* Deterministic "art plate" that encodes the unit's own structure:
     rings = number of sections, bands = topics, dots = quiz items. */
  function artSVG(u, thumb) {
    var pal = PALETTES[u.grade] || PALETTES['المرحلة المتوسطة'];
    var rnd = rng(seedFrom(u.id + u.title));
    var W = 600, H = thumb ? 400 : 800, cx = W / 2, cy = H * 0.46;
    var rings = Math.max(3, u.sections.length + 1);
    var out = [];
    var gid = 'ag' + u.id;
    out.push('<svg viewBox="0 0 ' + W + ' ' + H + '" class="agsvg" preserveAspectRatio="xMidYMid slice" role="img" aria-label="لوحة توليدية من محتوى الوحدة">');
    out.push('<defs>' +
      '<radialGradient id="' + gid + 'bg" cx="50%" cy="42%" r="70%">' +
      '<stop offset="0" stop-color="' + pal[3] + '"/><stop offset="1" stop-color="#0e1219"/></radialGradient>' +
      '<linearGradient id="' + gid + 'st" x1="0" y1="0" x2="1" y2="1">' +
      '<stop offset="0" stop-color="' + pal[0] + '"/><stop offset=".5" stop-color="' + pal[1] + '"/><stop offset="1" stop-color="' + pal[2] + '"/></linearGradient>' +
      '</defs>');
    out.push('<rect width="' + W + '" height="' + H + '" fill="url(#' + gid + 'bg)"/>');
    /* band field: one band per topic */
    for (var i = 0; i < u.sections.length; i++) {
      var y = 40 + i * (H - 80) / Math.max(1, u.sections.length);
      out.push('<path d="M0 ' + y + ' Q ' + (W * 0.5) + ' ' + (y + 40 * Math.sin(i + 1)) + ' ' + W + ' ' + (y - 20) + '" ' +
        'stroke="' + pal[i % 3] + '" stroke-opacity=".28" stroke-width="' + (2 + (i % 3)) + '" fill="none"/>');
    }
    /* rings */
    for (var r = 0; r < rings; r++) {
      var rad = 46 + r * 26;
      var dash = (r % 2 === 0) ? 'stroke' : 'fill';
      if (dash === 'stroke') {
        out.push('<circle cx="' + cx + '" cy="' + cy + '" r="' + rad + '" fill="none" stroke="' + pal[r % 3] +
          '" stroke-opacity="' + (0.55 - r * 0.05).toFixed(2) + '" stroke-width="' + (r === 0 ? 10 : 2) + '"/>');
      } else {
        out.push('<circle cx="' + cx + '" cy="' + cy + '" r="' + rad + '" fill="none" stroke="' + pal[r % 3] +
          '" stroke-opacity=".45" stroke-width="1.6" stroke-dasharray="4 ' + (7 + r) + '"/>');
      }
    }
    /* pigment splashes */
    var splashes = [];
    for (var s2 = 0; s2 < 9; s2++) {
      var ang = rnd() * Math.PI * 2, dist = 90 + rnd() * 150;
      splashes.push('<circle cx="' + (cx + Math.cos(ang) * dist).toFixed(1) + '" cy="' + (cy + Math.sin(ang) * dist).toFixed(1) +
        '" r="' + (3 + rnd() * 11).toFixed(1) + '" fill="' + pal[Math.floor(rnd() * 3)] + '" fill-opacity="' + (0.18 + rnd() * 0.4).toFixed(2) + '"/>');
    }
    out.push(splashes.join(''));
    /* a horizon + vanishing lines hint (perspective motif) */
    out.push('<line x1="0" y1="' + (H * 0.78) + '" x2="' + W + '" y2="' + (H * 0.78) + '" stroke="#fff" stroke-opacity=".14" stroke-width="1.2" stroke-dasharray="7 6"/>');
    out.push('<circle cx="' + cx + '" cy="' + (H * 0.78) + '" r="4.5" fill="' + pal[1] + '"/>');
    /* arc signature */
    out.push('<path d="M' + (W * 0.14) + ' ' + (H * 0.9) + ' C ' + (W * 0.35) + ' ' + (H * 0.62) + ', ' + (W * 0.65) + ' ' + (H * 0.62) + ', ' + (W * 0.86) + ' ' + (H * 0.9) +
      '" fill="none" stroke="url(#' + gid + 'st)" stroke-width="' + (thumb ? 9 : 12) + '" stroke-linecap="round"/>');
    /* label */
    if (!thumb) {
      out.push('<text x="' + cx + '" y="' + (H * 0.96) + '" text-anchor="middle" fill="#cfd6e4" fill-opacity=".55" ' +
        'font-family="Cairo, sans-serif" font-size="16">' + esc(u.title.replace(/^الصف \S+ المتوسط - /, '')) + '</text>');
    }
    out.push('</svg>');
    return out.join('');
  }
  function galleryFor(id, index) {
    var u = C.units.filter(function (x) { return x.id === id; })[0];
    if (!u) return;
    var items = [{ type: 'gen' }].concat((u.plates || []).map(function (f) { return { type: 'plate', src: 'media/' + f }; }));
    var html = '<div class="lightbox" id="lightbox"><button class="lb-close" aria-label="إغلاق">✕</button>' +
      '<div class="lb-stage">' + items.map(function (it, i) {
        return '<div class="lb-item' + (i === (index || 0) ? ' on' : '') + '">' +
          (it.type === 'gen' ? artSVG(u, false) : '<img src="' + it.src + '" alt="لوحة من دليل المعلم" data-lbimg>') + '</div>';
      }).join('') + '</div>' +
      '<div class="lb-nav"><button data-lb="prev">›</button><span id="lbCount"></span><button data-lb="next">‹</button></div>' +
      '<p class="lb-cap">' + esc(u.title) + ' · ' + esc(unitShort(u)) + ' · دليل المعلم ص ' + arDigit(u.pages || '—') + '</p></div>';
    var host = document.createElement('div');
    host.innerHTML = html;
    document.body.appendChild(host.firstChild);
    var lb = $('#lightbox');
    var cur = index || 0;
    var list = $$('.lb-item', lb);
    /* keep the neighbours loaded so prev/next is instant */
    Array.prototype.forEach.call(lb.querySelectorAll('img'), function (im) { im.loading = 'eager'; });
    function show(i) {
      cur = (i + list.length) % list.length;
      list.forEach(function (el, k) { el.classList.toggle('on', k === cur); });
      $('#lbCount').textContent = arDigit(cur + 1) + ' / ' + arDigit(list.length);
    }
    show(cur);
    lb.addEventListener('click', function (e) {
      if (e.target.closest('.lb-close') || e.target === lb) { lb.remove(); return; }
      var n = e.target.closest('[data-lb]');
      if (n) show(cur + (n.dataset.lb === 'next' ? 1 : -1));
    });
  }

  /* ---------------- search ---------------- */
  function buildSearchDocs() {
    var docs = [];
    C.units.forEach(function (u) {
      docs.push({ kind: 'وحدة', label: u.title, text: u.objectives || '', nav: { unit: u.id } });
      (u.sections || []).forEach(function (s, i) {
        docs.push({ kind: 'موضوع', label: s.title, text: (s.paras || []).join(' '), nav: { unit: u.id, sec: 'sec-' + i } });
      });
      (u.summary || []).forEach(function (s) {
        docs.push({ kind: 'خلاصة', label: shorten(s, 70), text: s, nav: { unit: u.id } });
      });
    });
    C.plans.forEach(function (p) {
      docs.push({ kind: 'خطة', label: p.title, text: [p.objectives, (p.specific || []).join(' '), p.intro, p.present].join(' '), nav: { plan: p.name } });
    });
    (C.intro.sections || []).forEach(function (s) {
      docs.push({ kind: 'دليل', label: s.title, text: (s.paras || []).join(' '), nav: { intro: 1 } });
    });
    return docs;
  }
  var SEARCH_DOCS = null;

  function doSearch(q) {
    if (!SEARCH_DOCS) SEARCH_DOCS = buildSearchDocs();
    q = q.trim();
    var host = $('#searchResults');
    if (q.length < 2) {
      host.innerHTML = '<div class="empty">اكتب كلمتين على الأقل للبحث في كل المحتوى.</div>';
      return;
    }
    var rx = new RegExp(q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'gi');
    var hits = [];
    SEARCH_DOCS.forEach(function (d) {
      if (rx.test(d.label)) {
        hits.push({ d: d, score: 3, snip: d.text.slice(0, 130) });
      } else {
        var m = rx.exec(d.text);
        if (m) {
          var start = Math.max(0, m.index - 55);
          hits.push({ d: d, score: 1, snip: (start > 0 ? '…' : '') + d.text.slice(start, start + 150) + '…' });
        }
      }
      rx.lastIndex = 0;
    });
    hits.sort(function (a, b) { return b.score - a.score; });
    if (!hits.length) {
      host.innerHTML = '<div class="empty">لا نتائج لـ «' + esc(q) + '».</div>';
      return;
    }
    host.innerHTML = hits.slice(0, 40).map(function (h) {
      var d = h.d;
      var nav = '';
      if (d.nav.unit) nav = ' data-unit="' + d.nav.unit + '"' + (d.nav.sec ? ' data-sec="' + d.nav.sec + '"' : '');
      else if (d.nav.plan) nav = ' data-plan="' + esc(d.nav.plan) + '"';
      else if (d.nav.intro) nav = ' data-go="intro"';
      return '<button class="sr-item"' + nav + '><div class="sr-meta">' + esc(d.kind) + '</div>' +
        '<div class="sr-t">' + highlight(d.label, q) + '</div>' +
        '<div class="sr-x">' + highlight(h.snip, q) + '</div></button>';
    }).join('');
  }
  function highlight(t, q) {
    var e = esc(t);
    var rx = new RegExp('(' + esc(q).replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + ')', 'gi');
    return e.replace(rx, '<mark>$1</mark>');
  }

  /* ---------------- render ---------------- */
  function render(name, params) {
    params = params || {};
    current = { name: name, params: params };
    var view = $('#view');
    var html = '';
    switch (name) {
      case 'home': html = viewHome(); break;
      case 'index': html = viewIndex(); break;
      case 'grade': html = viewGrade(params); break;
      case 'unit': html = viewUnit(params); break;
      case 'plans': html = viewPlans(); break;
      case 'plan': html = viewPlan(params); break;
      case 'intro': html = viewIntro(); break;
      case 'studio': html = viewStudio(); break;
      case 'quiz': html = viewQuiz(params); break;
      case 'result': html = viewResult(); break;
      default: html = viewHome();
    }
    view.innerHTML = html;
    view.scrollTop = 0;
    window.scrollTo(0, 0);
    if (name !== 'unit') { $('#readProgress').style.width = '0'; document.body.classList.remove('serif', 'large'); }
    setTab(name === 'grade' || name === 'unit' ? 'index' : name);
    var t = TITLES[name] || 'ريبو';
    if (name === 'unit') {
      var u = C.units.filter(function (x) { return x.id === params.id; })[0];
      if (u) t = u.title.replace(/^الصف \S+ المتوسط - /, '');
    }
    if (name === 'plan') {
      var p = C.plans.filter(function (x) { return x.name === params.id; })[0];
      if (p) t = p.title;
    }
    if (name === 'grade') t = params.grade || 'الوحدات';
    setTitle(t);
    if (name === 'unit' && params.anchor) {
      setTimeout(function () {
        var el = document.getElementById(params.anchor);
        if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }, 120);
    }
  }

  /* ---------------- events ---------------- */
  document.addEventListener('click', function (e) {
    var t = e.target.closest('[data-go],[data-unit],[data-plan],[data-grade],[data-filter],[data-sec],[data-quiz],[data-gallery],[data-ans],[data-next],[data-retry],[data-toggle],[data-toc]');
    if (!t) return;

    if (t.dataset.go) { closeDrawer(); return go(t.dataset.go, {}); }
    if (t.dataset.unit) {
      closeDrawer();
      var p = { id: t.dataset.unit };
      if (t.dataset.sec) p.anchor = t.dataset.sec;
      hideSearch();
      return go('unit', p);
    }
    if (t.dataset.plan) { closeDrawer(); hideSearch(); return go('plan', { id: t.dataset.plan }); }
    if (t.dataset.grade) { closeDrawer(); return go('grade', { grade: t.dataset.grade }); }
    if (t.dataset.filter) {
      store.set('indexFilter', t.dataset.filter);
      render('index', {});
      return;
    }
    if (t.dataset.gallery) {
      galleryFor(t.dataset.gallery, t.dataset.gi ? +t.dataset.gi : 0);
      return;
    }
    if (t.dataset.sec) {
      var el = document.getElementById(t.dataset.sec);
      if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' });
      return;
    }
    if (t.dataset.quiz) { return go('quiz', { id: t.dataset.quiz }); }
    if (t.dataset.toggle) {
      var k = t.dataset.toggle;
      var v = !store.get(k, false);
      store.set(k, v);
      document.body.classList.toggle(k, v);
      t.classList.toggle('active', v);
      return;
    }
    if (t.dataset.toc) {
      var first = $('#sec-0');
      if (first) first.scrollIntoView({ behavior: 'smooth', block: 'start' });
      return;
    }
    if (t.dataset.ans != null) {
      if (quizState.answered) return;
      var i = +t.dataset.ans;
      var q = quizState.pool[quizState.i];
      quizState.log[quizState.i] = i;
      if (i === q.answer) quizState.score++;
      quizState.answered = true;
      render('quiz', { id: quizState.unitId });
      return;
    }
    if (t.dataset.next) {
      quizState.answered = false;
      if (quizState.i + 1 < quizState.pool.length) {
        quizState.i++;
        render('quiz', { id: quizState.unitId });
      } else {
        render('result', {});
        setTitle('النتيجة');
      }
      return;
    }
    if (t.dataset.retry) { newQuiz(quizState.unitId); return render('quiz', { id: quizState.unitId }); }
  });

  /* tabs */
  $$('.tab').forEach(function (b) {
    b.addEventListener('click', function () {
      var r = b.dataset.route;
      if (r === 'quiz') { newQuiz(null); return go('quiz', {}); }
      go(r, {});
    });
  });

  /* drawer */
  function openDrawer() {
    $('#drawer').classList.add('open');
    $('#scrim').classList.add('open');
    $('#drawer').setAttribute('aria-hidden', 'false');
  }
  function closeDrawer() {
    $('#drawer').classList.remove('open');
    $('#scrim').classList.remove('open');
    $('#drawer').setAttribute('aria-hidden', 'true');
  }
  $('#menuBtn').addEventListener('click', openDrawer);
  $('#scrim').addEventListener('click', closeDrawer);

  /* search */
  function openSearch() {
    $('#searchPanel').hidden = false;
    setTimeout(function () { $('#searchInput').focus(); }, 60);
    doSearch($('#searchInput').value || '');
  }
  function hideSearch() { $('#searchPanel').hidden = true; }
  $('#searchBtn').addEventListener('click', openSearch);
  $('#searchClose').addEventListener('click', hideSearch);
  $('#searchInput').addEventListener('input', function (e) { doSearch(e.target.value); });
  document.addEventListener('keydown', function (e) {
    if ((e.ctrlKey || e.metaKey) && e.key === 'f') { e.preventDefault(); openSearch(); }
    if (e.key === 'Escape') { hideSearch(); closeDrawer(); }
  });

  /* fullscreen */
  $('#fsBtn').addEventListener('click', function () {
    var d = document;
    if (!d.fullscreenElement) {
      (d.documentElement.requestFullscreen || function () {}).call(d.documentElement);
    } else {
      (d.exitFullscreen || function () {}).call(d);
    }
  });

  /* android back button (WebView2/Android hardware back) */
  window.addEventListener('keydown', function (e) {
    if (e.key === 'Backspace' && !/input|textarea/i.test(document.activeElement.tagName)) {
      /* no-op, handled natively */
    }
  });

  /* drawer nav */
  function buildDrawerNav() {
    var nav = $('#drawerNav');
    nav.innerHTML = [
      ['home', 'الرئيسية'], ['index', 'الفهرس'], ['plans', 'خطط الدروس'],
      ['studio', 'المختبر الفني'], ['quiz', 'اختبر نفسك'], ['intro', 'المقدمة']
    ].map(function (r) {
      return '<button data-go="' + r[0] + '"><span class="dot"></span>' + r[1] + '</button>';
    }).join('') + '<div style="height:10px"></div>' +
      Object.keys(GRADE_META).map(function (grade) {
        var units = C.units.filter(function (u) { return u.grade === grade; });
        if (!units.length) return '';
        return '<span class="drawer-sec">' + esc(grade) + '</span>' +
          units.map(function (u) {
            var topic = (u.title || '').split(' - ').pop().replace(/^الوحدة[^:]{0,12}:\s*/, '');
            return '<button data-unit="' + u.id + '"><span class="dot" style="color:' + gmeta(grade).color + '"></span>' +
              esc(unitShort(u) + ' · ' + shorten(topic, 30)) + '</button>';
          }).join('');
      }).join('');
  }

  /* ---------------- boot ---------------- */
  function boot() {
    $('#statUnits').textContent = arDigit(C.units.length);
    $('#statPlans').textContent = arDigit(C.plans.length);
    $('#statQ').textContent = arDigit(totalQuestions());
    buildDrawerNav();
    var p = parseHash();
    render(p.name, p.params);
    depth = 0;
    $('#app').hidden = false;
    var splash = $('#splash');
    if (splash) {
      /* the overlay also fades itself via CSS, so a throttled timer can never
         leave the app stuck behind the splash screen */
      splash.addEventListener('animationend', function () { if (splash.parentNode) splash.remove(); });
      setTimeout(function () {
        splash.classList.add('hide');
        setTimeout(function () { if (splash.parentNode) splash.remove(); }, 600);
      }, 850);
    }
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
  else boot();
})();
