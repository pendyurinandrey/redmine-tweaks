/* Redmine Tweaks — helpers shared by the features (loaded first). */
(function () {
  'use strict';

  var texts = {};
  try {
    var meta = document.querySelector('meta[name="redmine-tweaks"]');
    if (meta) { texts = JSON.parse(meta.getAttribute('content')) || {}; }
  } catch (e) { /* the fallbacks passed to t() are used */ }

  window.RedmineTweaks = window.RedmineTweaks || {};

  // Text translated on the server (see lib/redmine_tweaks/hooks.rb) or the given English fallback
  window.RedmineTweaks.t = function (key, fallback) { return texts[key] || fallback; };

  // True if any field of the form differs from the values saved on the server (the defaults of the rendered form)
  window.RedmineTweaks.isDirty = function (form) {
    return Array.prototype.some.call(form.elements, function (el) {
      switch (el.type) {
        case 'hidden': case 'submit': case 'button': case 'reset': return false;
        case 'checkbox': case 'radio': return el.checked !== el.defaultChecked;
        case 'file': return !!(el.files && el.files.length);
        case 'select-one': case 'select-multiple':
          return Array.prototype.some.call(el.options, function (o) { return o.selected !== o.defaultSelected; });
        default: return el.value !== el.defaultValue;
      }
    });
  };
})();
