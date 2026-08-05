const test = require("node:test");
const assert = require("node:assert/strict");

const {
  didTakeLead,
  repsToRetakeLead,
} = require("../lib/competition.js");

test("detects only a score crossing from behind to ahead", () => {
  assert.equal(didTakeLead(9, 11, 10), true);
  assert.equal(didTakeLead(11, 12, 10), false);
  assert.equal(didTakeLead(9, 10, 10), false);
  assert.equal(didTakeLead(10, 9, 8), false);
});

test("calculates the reps needed to take the lead back", () => {
  assert.equal(repsToRetakeLead(11, 10), 2);
  assert.equal(repsToRetakeLead(30, 12), 19);
});
