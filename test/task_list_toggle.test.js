// Unit tests for the pure logic of the task-list feature. Run: node --test test/
const test = require('node:test');
const assert = require('node:assert/strict');
const { findTaskMarkers, setMarker } = require('../assets/javascripts/task_list_toggle.js');

const states = (text) => findTaskMarkers(text).map((m) => m.checked);
const charAt = (text) => findTaskMarkers(text).map((m) => text[m.pos]);

test('finds unchecked and checked items with -, *, +, numbered and nested lists', () => {
  const src = '- [ ] a\n- [x] b\n  - [ ] c\n* [X] d\n+ [ ] e\n1. [ ] f\n2) [x] g\n';
  assert.deepEqual(states(src), [false, true, false, true, false, false, true]);
  assert.deepEqual(charAt(src), [' ', 'x', ' ', 'X', ' ', ' ', 'x']);
});

test('ignores fenced code blocks (backticks and tildes, longer closing fences)', () => {
  const src = '- [ ] real1\n\n```\n- [ ] in code\n```\n\n~~~\n- [x] tilde code\n~~~~\n\n````md\n```\n- [ ] nested fence text\n```\n````\n- [x] real2\n';
  assert.deepEqual(states(src), [false, true]);
});

test('ignores things that are not task items', () => {
  const src = 'text `- [ ] inline` end\n- item with [ ] inside\n- [ ]no-space\n[ ] no list marker\n-[ ] no space after dash\n';
  assert.deepEqual(states(src), []);
});

test('task item may end the line or be followed by more spaces', () => {
  assert.deepEqual(states('- [ ]\n- [x]   text\n'), [false, true]);
});

test('works inside blockquotes and with CRLF line endings', () => {
  const src = '> - [ ] quoted\r\n- [x] crlf\r\n';
  assert.deepEqual(states(src), [false, true]);
  const marks = findTaskMarkers(src);
  assert.equal(setMarker(src, marks[1], false), '> - [ ] quoted\r\n- [ ] crlf\r\n');
});

test('setMarker changes exactly one character', () => {
  const src = 'Intro\n\n- [ ] one\n- [x] two\n\n```\n- [ ] code\n```\n\n- [ ] three\n';
  const marks = findTaskMarkers(src);
  assert.equal(marks.length, 3);
  const flipped = setMarker(src, marks[2], true);
  assert.equal(flipped, src.replace('- [ ] three', '- [x] three'));
  assert.equal(setMarker(src, marks[1], false), src.replace('- [x] two', '- [ ] two'));
  assert.equal(flipped.length, src.length);
  // the code block is untouched
  assert.ok(flipped.includes('```\n- [ ] code\n```'));
});

test('Cyrillic and other non-ASCII text does not shift positions', () => {
  const src = 'Слайды:\n\n- [ ] Слайд 7 — что делать с «фейковыми» данными\n- [x] Вставить фото\n';
  const marks = findTaskMarkers(src);
  assert.deepEqual(marks.map((m) => m.checked), [false, true]);
  assert.equal(setMarker(src, marks[0], true), src.replace('- [ ] Слайд 7', '- [x] Слайд 7'));
});

test('markers in a description without any list return nothing', () => {
  assert.deepEqual(findTaskMarkers(''), []);
  assert.deepEqual(findTaskMarkers('just text\nmore text'), []);
});
