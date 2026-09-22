// OI Wiki print theme for Typst 0.15.0.
// Keep this module dependency-free: the generated book supplies mitex itself.

#let navy = rgb("17324d")
#let cyan = rgb("168c96")
#let ink = rgb("202832")
#let muted = rgb("667381")
#let paper = rgb("ffffff")
#let panel = rgb("f3f7f8")
#let rule = rgb("d3dde2")
#let body-font = ("LiSong Pro", "New Computer Modern")
#let heading-font = ("LXGW WenKai GB Screen R", "PingFang SC")
#let code-font = ("DejaVu Sans Mono", "Menlo")
#let math-font = ("New Computer Modern Math", "LiSong Pro")

#let _kind-label(kind) = {
  if kind == "tip" { "技巧" }
  else if kind == "warning" { "注意" }
  else if kind == "danger" { "危险" }
  else if kind == "success" { "成功" }
  else if kind == "question" { "问题" }
  else if kind == "failure" { "失败" }
  else if kind == "bug" { "缺陷" }
  else if kind == "example" { "示例" }
  else if kind == "quote" { "引用" }
  else if kind == "abstract" { "摘要" }
  else if kind == "info" { "信息" }
  else { "说明" }
}

#let _kind-accent(kind) = {
  if kind == "warning" or kind == "danger" or kind == "failure" { rgb("9a563f") }
  else if kind == "success" or kind == "tip" { cyan }
  else { navy }
}

#let admonition(kind: "note", title: none, body) = {
  let accent = _kind-accent(kind)
  let label = if title == none { _kind-label(kind) } else { title }
  block(
    width: 100%,
    breakable: true,
    fill: panel,
    stroke: (left: 3pt + accent, top: 0.4pt + rule, right: 0.4pt + rule, bottom: 0.4pt + rule),
    inset: (left: 10pt, right: 9pt, top: 7pt, bottom: 8pt),
    radius: (right: 3pt),
    [
      #text(font: heading-font, weight: 600, fill: accent)[#label]
      #v(3pt)
      #body
    ],
  )
}

// Compatibility with pymdownx-details output from remark-typst.
#let details(type: "note", unwrap: false, ..items) = {
  let values = items.pos()
  if values.len() != 2 {
    panic("#details receives exactly two content blocks")
  }
  let (title, body) = values
  if unwrap {
    [
      #text(font: heading-font, weight: 600, fill: _kind-accent(type))[#title]
      #v(3pt)
      #body
    ]
  } else {
    admonition(kind: type, title: title, body)
  }
}

#let sourcecode(body, highlight_color: cyan.lighten(75%)) = {
  show raw.where(block: true): it => {
    let language = if it.lang == none or it.lang == "" { "CODE" } else { it.lang }
    set par(justify: false, linebreaks: "optimized")
    block(
      width: 100%,
      breakable: true,
      fill: panel,
      stroke: 0.6pt + rule,
      inset: 6pt,
      radius: 3pt,
      [
        #align(right, text(size: 6.8pt, font: heading-font, fill: muted, weight: 600)[#language])
        #v(-3pt)
        #text(size: 8.6pt, font: code-font, fill: ink)[#it]
      ],
    )
  }
  body
}

#let blockquote(content) = block(
  width: 100%,
  breakable: true,
  stroke: (left: 2pt + rule),
  inset: (left: 10pt, y: 4pt),
  text(fill: muted, style: "italic", content),
)

#let authors(value) = blockquote[
  #text(font: heading-font, weight: 600, style: "normal")[作者：]
  #value
]

#let kbd(value) = box(
  inset: (x: 3pt, y: 1pt),
  outset: (y: 1pt),
  fill: paper,
  stroke: (x: 0.5pt + muted, top: 0.5pt + muted, bottom: 1.4pt + muted),
  radius: 2pt,
  text(size: 8pt, font: code-font, fill: ink, raw(value)),
)

#let img-auto(src, alt: "") = align(
  center,
  block(
    width: 100%,
    breakable: false,
    image(src, alt: alt, width: 100%, fit: "contain"),
  ),
)

#let svg-math(svg, display: false) = {
  let rendered = image(svg)
  if display { align(center, rendered) } else { box(rendered) }
}

#let tablex-custom(columns: (), aligns: (), ..cells) = {
  let values = cells.pos()
  let column-count = if type(columns) == int { columns } else { columns.len() }
  let resolved-columns = if type(columns) == int { (1fr,) * columns } else { columns }
  let head-count = calc.min(column-count, values.len())
  let head = values.slice(0, head-count)
  let rest = values.slice(head-count)
  let cell-align = (x, _) => if aligns.len() > x { aligns.at(x) } else { left }
  align(
    center,
    block(
      width: 100%,
      breakable: true,
      text(
        size: 8.5pt,
        table(
          columns: resolved-columns,
          align: cell-align,
          inset: (x: 5pt, y: 4pt),
          stroke: (_, y) => if y == 0 {
            (top: 0.8pt + navy, bottom: 0.6pt + rule, x: none)
          } else {
            (bottom: 0.35pt + rule, x: none, top: none)
          },
          table.header(repeat: true, ..head),
          ..rest,
        ),
      ),
    ),
  )
}

#let tabbed(unwrap: false, ..items) = {
  let values = items.pos()
  if values.len() != 2 {
    panic("#tabbed receives exactly two content blocks")
  }
  let (label, body) = values
  if unwrap {
    [#text(font: heading-font, weight: 600, fill: navy)[#label] #body]
  } else {
    block(
      width: 100%,
      breakable: true,
      stroke: (left: 2pt + cyan),
      inset: (left: 9pt, y: 4pt),
      [
        #text(font: heading-font, weight: 600, fill: navy)[#label]
        #v(3pt)
        #body
      ],
    )
  }
}

#let horizontalrule = align(center, line(length: 38%, stroke: 0.6pt + rule))

#let page-header = context {
  let current = here()
  let articles = query(heading.where(level: 2).before(current))
  let sections = query(heading.where(level: 1).before(current))
  let running = if calc.odd(current.page()) {
    if articles.len() > 0 { articles.last().body } else { [OI Wiki] }
  } else {
    if sections.len() > 0 { sections.last().body } else { [OI Wiki] }
  }
  block(
    width: 100%,
    below: 7pt,
    stroke: (bottom: 0.45pt + rule),
    inset: (bottom: 4pt),
    text(size: 8pt, font: heading-font, fill: muted)[#running],
  )
}

#let book-theme(body) = {
  set document(title: "OI Wiki", author: "OI Wiki Team")
  set page(
    paper: "a4",
    margin: (inside: 24mm, outside: 19mm, top: 21mm, bottom: 22mm),
    binding: left,
    fill: paper,
  )
  set text(size: 10pt, fill: ink, font: body-font, lang: "zh", region: "cn")
  set par(justify: true, leading: 0.72em, linebreaks: "optimized")
  set block(spacing: 0.78em)
  set heading(numbering: "1.1")
  set list(indent: 1.7em, body-indent: 0.5em)
  set enum(indent: 1.7em, body-indent: 0.5em)

  show heading: set text(font: heading-font, fill: navy, weight: 600)
  show heading.where(level: 1): it => block(above: 16pt, below: 12pt, breakable: false, text(size: 23pt, it))
  show heading.where(level: 2): it => block(above: 12pt, below: 8pt, breakable: false, text(size: 16pt, it))
  show heading.where(level: 3): set text(size: 13pt)
  show heading.where(level: 4): set text(size: 11pt)
  show link: set text(fill: cyan)
  show ref: set text(fill: cyan)
  show emph: set text(fill: ink)
  show math.equation: set text(font: math-font)
  show raw: set text(font: code-font)
  show raw.where(block: false): it => box(fill: panel, inset: (x: 3pt, y: 1pt), radius: 2pt, it)
  show raw.where(block: true): set text(size: 8.6pt, font: code-font)
  show footnote.entry: set text(size: 8.5pt, fill: muted)
  show figure.caption: set text(size: 8.5pt, fill: muted)
  show table: set text(size: 8.8pt)
  show quote: it => blockquote(it.body)

  body
}
