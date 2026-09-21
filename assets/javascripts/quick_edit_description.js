/* Redmine Tweaks — feature "quick edit description" (needs tweaks_common.js).
 *
 * A pencil next to the "Description" label of the issue page opens Redmine's own edit form, expands the (normally
 * collapsed) description editor, scrolls to it and puts the cursor at the end of the text. Nothing is re-implemented:
 * saving, previews, attachments, the version lock and the journal all stay Redmine's.
 *
 * Leaving the edit mode:
 *   - Esc in a text field of the form (asks before discarding unsaved changes),
 *   - Redmine's own "Cancel" link (keeps what was typed, as before),
 *   - Ctrl/Cmd+Enter saves (Redmine core behavior).
 *
 * The pencil appears only when the current user may edit the description: the editor markup
 * (#issue_description_and_toolbar) exists only then.
 */
(function () {
  'use strict';

  var t = window.RedmineTweaks.t;
  var isDirty = window.RedmineTweaks.isDirty;

  function autocompleteOpen() {
    var menu = document.querySelector('.tribute-container');
    return !!(menu && menu.style.display !== 'none' && menu.offsetParent !== null);
  }

  function init() {
    var box         = document.getElementById('issue_description_and_toolbar'); // editor wrapper (hidden by default)
    var field       = document.getElementById('issue_description');
    var updateForm  = document.getElementById('update');                        // whole edit block of the issue page
    var form        = document.getElementById('issue-form');
    if (!box || !field || !updateForm || !form) { return; }                     // no right to edit the description

    // Redmine's own small "Edit" link that expands the editor inside the form (next to the "Description" label)
    var expandLink = box.parentNode.querySelector('a.icon-edit');

    function openEditor() {
      box.style.display = '';
      if (expandLink) { expandLink.style.display = 'none'; }
      if (typeof window.showAndScrollTo === 'function') {
        window.showAndScrollTo('update', 'issue_description');
      } else {
        updateForm.style.display = '';
      }
      field.focus({ preventScroll: true });
      field.setSelectionRange(field.value.length, field.value.length);
      field.scrollIntoView({ block: 'center' });
    }

    function closeEditor() {
      if (isDirty(form) && !window.confirm(t('discard_changes', 'Discard the unsaved changes?'))) { return; }
      form.reset();                                                             // back to the saved values
      if (window.jQuery) { window.jQuery(form).find('textarea').removeData('changed'); } // no "unsaved changes" prompt on leave
      updateForm.style.display = 'none';                                        // what Redmine's "Cancel" does
      box.style.display = 'none';
      if (expandLink) { expandLink.style.display = ''; }
      if (pencil) { pencil.focus({ preventScroll: true }); pencil.scrollIntoView({ block: 'nearest' }); }
    }

    // Esc in a text field of the form leaves the edit mode
    form.addEventListener('keydown', function (e) {
      if (e.key !== 'Escape' || e.defaultPrevented || e.isComposing) { return; }
      var el = e.target;
      if (!el.matches || !el.matches('textarea, input[type="text"]')) { return; }
      if (autocompleteOpen()) { return; }                                       // Esc closes the @-mention menu first
      e.preventDefault();
      closeEditor();
    });

    // --- the pencil -------------------------------------------------------------------------------------------------
    var label   = t('edit_description', 'Edit description');
    var pencil  = document.createElement('button');
    pencil.type = 'button';
    pencil.className = 'rt-edit-description';
    pencil.title = label;
    pencil.setAttribute('aria-label', label);
    var editIcon = document.querySelector('#content .contextual a.icon-edit svg');
    if (editIcon) { pencil.appendChild(editIcon.cloneNode(true)); } else { pencil.textContent = '✎'; }
    pencil.addEventListener('click', openEditor);

    var block = document.querySelector('div.description');
    var heading = block && block.querySelector('p > strong');
    if (heading) {
      heading.parentNode.appendChild(pencil);
    } else {
      // Issue without a description: Redmine renders no description block at all, so add a slim one
      var labelEl = form.querySelector('label[for="issue_description"]');
      var attributes = document.querySelector('.issue.details .attributes, div.issue .attributes');
      if (!attributes) { return; }
      var wrapper = document.createElement('div');
      wrapper.className = 'description rt-edit-description-empty';
      var p = document.createElement('p');
      var strong = document.createElement('strong');
      strong.textContent = labelEl ? labelEl.textContent.replace('*', '').trim() : 'Description';
      p.appendChild(strong);
      p.appendChild(pencil);
      wrapper.appendChild(p);
      attributes.insertAdjacentElement('afterend', wrapper);
      wrapper.insertAdjacentElement('beforebegin', document.createElement('hr')); // same divider as above a real description
    }
  }

  if (document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', init); } else { init(); }
})();
