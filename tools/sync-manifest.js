#!/usr/bin/env node
// Regenerates manifest.json's "style" enum options from Styles.js, the single
// source of truth. Run this after adding, removing, or renaming any style.
//
// The label carries the style's own glyph so the dropdown shows what it means
// rather than only naming it, the same trick tools/sync-menu.js uses for the
// menu picker's icon column.
"use strict"

const fs = require("fs")
const path = require("path")

const root = path.join(__dirname, "..")
const { styles, glyphChar } = require(path.join(root, "Styles.js"))

const manifestPath = path.join(root, "manifest.json")
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"))

const options = styles().map(function (s) {
  return { value: s.id, label: glyphChar(s.icon) + "  " + s.label, description: s.description }
})

const styleField = manifest.barWidget.schema.find(function (f) { return f.key === "style" })
if (!styleField) throw new Error('manifest.json has no "style" schema field')
styleField.options = options

fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + "\n")
console.log("Wrote " + options.length + " style options to manifest.json")
