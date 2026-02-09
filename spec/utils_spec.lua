-- Utils tests that exercise pure-ish functions.
-- Some utils functions depend on vim.fn (buffer state), so we test
-- the subset that can run without complex buffer setup.

local utils = require("autolist.utils")

-- Ensure config is initialized
require("autolist.config").update()

local list_types = { "[-+*]", "%d+[.)]", "%a[.)]", "%u+[.)]" }

describe("utils", function()
  describe("is_blank_line", function()
    it("returns true for empty string", function()
      assert.is_true(utils.is_blank_line(""))
    end)

    it("returns true for spaces only", function()
      assert.is_true(utils.is_blank_line("   "))
    end)

    it("returns true for tab only", function()
      assert.is_true(utils.is_blank_line("\t"))
    end)

    it("returns false for list item", function()
      assert.is_false(utils.is_blank_line("- item"))
    end)

    it("returns false for indented list item", function()
      assert.is_false(utils.is_blank_line("  1. item"))
    end)
  end)

  describe("get_indent_lvl", function()
    it("returns 0 for no indent", function()
      assert.are.equal(0, utils.get_indent_lvl("- item"))
    end)

    it("counts leading spaces", function()
      assert.are.equal(2, utils.get_indent_lvl("  - item"))
      assert.are.equal(4, utils.get_indent_lvl("    - item"))
    end)

    it("counts a tab as one character", function()
      assert.are.equal(1, utils.get_indent_lvl("\t- item"))
    end)

    it("returns 0 for empty string", function()
      assert.are.equal(0, utils.get_indent_lvl(""))
    end)
  end)

  describe("get_whitespace_trimmed", function()
    it("trims trailing whitespace", function()
      assert.are.equal("hello", utils.get_whitespace_trimmed("hello   "))
    end)

    it("does not trim leading whitespace", function()
      assert.are.equal("  hello", utils.get_whitespace_trimmed("  hello  "))
    end)
  end)

  describe("get_percent_filtered", function()
    it("removes percent signs", function()
      assert.are.equal("[x]", utils.get_percent_filtered("%[x%]"))
      assert.are.equal("[ ]", utils.get_percent_filtered("%[ %]"))
    end)
  end)

  describe("is_list", function()
    it("detects unordered list markers", function()
      assert.is_truthy(utils.is_list("- item", list_types))
      assert.is_truthy(utils.is_list("+ item", list_types))
      assert.is_truthy(utils.is_list("* item", list_types))
    end)

    it("detects indented unordered markers", function()
      assert.is_truthy(utils.is_list("  - item", list_types))
      assert.is_truthy(utils.is_list("    * item", list_types))
    end)

    it("detects digit ordered markers", function()
      assert.is_truthy(utils.is_list("1. item", list_types))
      assert.is_truthy(utils.is_list("12. item", list_types))
      assert.is_truthy(utils.is_list("1) item", list_types))
    end)

    it("detects ascii ordered markers", function()
      assert.is_truthy(utils.is_list("a) item", list_types))
      assert.is_truthy(utils.is_list("b. item", list_types))
    end)

    it("detects roman numeral markers", function()
      assert.is_truthy(utils.is_list("I. item", list_types))
      assert.is_truthy(utils.is_list("IV. item", list_types))
      assert.is_truthy(utils.is_list("XII) item", list_types))
    end)

    it("rejects non-list lines", function()
      assert.is_falsy(utils.is_list("just some text", list_types))
      assert.is_falsy(utils.is_list("", list_types))
      assert.is_falsy(utils.is_list("   ", list_types))
    end)

    it("rejects Quarto fragment separator (. . .)", function()
      assert.is_falsy(utils.is_list(". . .", list_types))
    end)

    it("rejects bold/italic markup starting with *", function()
      assert.is_falsy(utils.is_list("**Mini-heading.**", list_types))
      assert.is_falsy(utils.is_list("*italic text*", list_types))
    end)

    it("rejects marker not followed by whitespace", function()
      assert.is_falsy(utils.is_list("-not a list", list_types))
      assert.is_falsy(utils.is_list("1.not a list", list_types))
    end)

    it("accepts bare marker at end of line", function()
      assert.is_truthy(utils.is_list("-", list_types))
      assert.is_truthy(utils.is_list("1.", list_types))
    end)

    it("returns the pattern and match on success", function()
      local is, pat, match = utils.is_list("- item", list_types)
      assert.is_truthy(is)
      assert.is_not_nil(pat)
      assert.are.equal("-", match)
    end)
  end)

  describe("get_marker", function()
    it("extracts marker from unordered list", function()
      assert.are.equal("-", utils.get_marker("- item", list_types))
      assert.are.equal("*", utils.get_marker("* item", list_types))
    end)

    it("extracts marker from ordered list", function()
      assert.are.equal("1.", utils.get_marker("1. item", list_types))
      assert.are.equal("3)", utils.get_marker("3) item", list_types))
    end)
  end)

  describe("get_value_ordered", function()
    it("returns digit value", function()
      assert.are.equal(1, utils.get_value_ordered("1. item"))
      assert.are.equal(42, utils.get_value_ordered("42. item"))
    end)

    it("returns ascii value (a=1, b=2, ...)", function()
      assert.are.equal(1, utils.get_value_ordered("a) item"))
      assert.are.equal(3, utils.get_value_ordered("c) item"))
    end)

    it("returns roman numeral value", function()
      assert.are.equal(1, utils.get_value_ordered("I. item"))
      assert.are.equal(4, utils.get_value_ordered("IV. item"))
      assert.are.equal(10, utils.get_value_ordered("X. item"))
    end)

    it("returns 0 for unordered lists", function()
      assert.are.equal(0, utils.get_value_ordered("- item"))
    end)
  end)

  describe("get_ordered_add", function()
    it("increments digit markers", function()
      assert.are.equal("2. item", utils.get_ordered_add("1. item", 1))
      assert.are.equal("11. item", utils.get_ordered_add("10. item", 1))
    end)

    it("increments ascii markers", function()
      assert.are.equal("b) item", utils.get_ordered_add("a) item", 1))
    end)

    it("increments roman markers", function()
      assert.are.equal("II. item", utils.get_ordered_add("I. item", 1))
    end)

    it("does not change unordered markers", function()
      assert.are.equal("- item", utils.get_ordered_add("- item", 1))
    end)

    it("defaults to increment of 1", function()
      assert.are.equal("2. item", utils.get_ordered_add("1. item"))
    end)
  end)

  describe("set_ordered_value", function()
    it("sets digit value", function()
      assert.are.equal("5. item", utils.set_ordered_value("1. item", 5))
    end)

    it("sets ascii value", function()
      assert.are.equal("c) item", utils.set_ordered_value("a) item", 3))
    end)

    it("sets roman value", function()
      assert.are.equal("V. item", utils.set_ordered_value("I. item", 5))
    end)

    it("leaves unordered unchanged", function()
      assert.are.equal("- item", utils.set_ordered_value("- item", 5))
    end)
  end)

  describe("get_content_width", function()
    it("returns 2 for '- '", function()
      assert.are.equal(2, utils.get_content_width("- item", list_types))
    end)

    it("returns 2 for '* '", function()
      assert.are.equal(2, utils.get_content_width("* item", list_types))
    end)

    it("returns 3 for '1. '", function()
      assert.are.equal(3, utils.get_content_width("1. item", list_types))
    end)

    it("returns 4 for '10. '", function()
      assert.are.equal(4, utils.get_content_width("10. item", list_types))
    end)

    it("returns 3 for 'a) '", function()
      assert.are.equal(3, utils.get_content_width("a) item", list_types))
    end)

    it("returns 3 for 'I. '", function()
      assert.are.equal(3, utils.get_content_width("I. item", list_types))
    end)

    it("returns 5 for 'III. '", function()
      assert.are.equal(5, utils.get_content_width("III. item", list_types))
    end)

    it("returns nil for non-list lines", function()
      assert.is_nil(utils.get_content_width("just text", list_types))
    end)

    it("handles indented lines", function()
      assert.are.equal(3, utils.get_content_width("   1. item", list_types))
    end)
  end)

  describe("is_ordered", function()
    it("returns truthy for ordered lists", function()
      assert.is_truthy(utils.is_ordered("1. item"))
      assert.is_truthy(utils.is_ordered("a) item"))
      assert.is_truthy(utils.is_ordered("I. item"))
    end)

    it("returns nil for unordered lists", function()
      assert.is_nil(utils.is_ordered("- item"))
      assert.is_nil(utils.is_ordered("* item"))
    end)

    it("returns nil for non-list lines", function()
      assert.is_nil(utils.is_ordered("just text"))
    end)

    it("returns nil for Quarto fragment separator", function()
      assert.is_nil(utils.is_ordered(". . ."))
    end)
  end)
end)
