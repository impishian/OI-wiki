#import "oi-wiki.typ" as upstream
#import "theme.typ": *

// Math helpers are supplied by the pinned official exporter module. Importing
// it as a namespace keeps its legacy layout helpers from shadowing our theme.
#let mi = upstream.mi
#let mitex = upstream.mitex

#show: book-theme

#let source-revision = sys.inputs.at("source-revision", default: "unknown")
#let build-date = sys.inputs.at("build-date", default: "unknown")
#let typst-version = sys.inputs.at("typst-version", default: "0.15.0")

#set page(header: none, footer: none, fill: panel)
#align(center + horizon)[
  #text(13pt, fill: cyan, tracking: 1.4pt)[COMPETITIVE PROGRAMMING HANDBOOK]
  #v(14mm)
  #text(36pt, font: heading-font, fill: navy, weight: 700)[OI Wiki]
  #v(4mm)
  #text(15pt, fill: muted)[信息学竞赛知识整合站点 · 完整典藏版]
  #v(38mm)
  #line(length: 45mm, stroke: 1.5pt + cyan)
  #v(8mm)
  #text(11pt, fill: muted)[OI Wiki Team · #build-date]
]

#pagebreak(to: "even")
#set page(fill: paper)
= 版本与许可
#table(
  columns: (34mm, 1fr),
  stroke: none,
  inset: (x: 0pt, y: 3pt),
  [源版本], [#source-revision],
  [排版系统], [Typst #typst-version],
  [生成日期], [#build-date],
  [项目网站], [#link("https://oi-wiki.org")],
)

#pagebreak(to: "odd")
#outline(title: [目录], depth: 3, indent: 1.4em)
#pagebreak(to: "odd")
#set page(
  header: page-header,
  footer: context align(center, text(size: 8pt, fill: muted, counter(page).display("1"))),
)
#counter(page).update(1)
#include "includes.typ"

#pagebreak(to: "odd")
#set page(header: none, footer: none, fill: navy)
#align(center + horizon, text(13pt, fill: white)[https://oi-wiki.org])
