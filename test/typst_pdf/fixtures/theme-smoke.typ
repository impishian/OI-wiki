#import "../../../scripts/typst-pdf/theme.typ": *
#show: book-theme

= 测试分部
== 代表文章

正文包含 #link("https://oi-wiki.org")[外部链接]、`inline_code`、脚注#footnote[脚注内容。] 与公式 $sum_(i=1)^n i$。

#admonition(kind: "tip", title: [技巧])[提示框内容。]

#sourcecode[```cpp
int main() { return 0; }
```]

#tablex-custom(
  columns: 2,
  aligns: (left, right),
  strong[算法], strong[复杂度],
  [二分], [$O(log n)$],
)

#grid(
  columns: (1fr, 1fr),
  gutter: 8pt,
  blockquote[引用文字。],
  tabbed[标签][分页内容。],
)

#details(type: "warning")[注意][灰度打印仍可通过标题和边框识别。]

按下 #kbd("Ctrl+C")；作者 #authors[OI Wiki Team]

矢量公式 #svg-math(bytes("<svg xmlns='http://www.w3.org/2000/svg' width='28' height='16'><text x='1' y='13'>x²</text></svg>"))。

#figure(
  box(width: 45mm)[#img-auto(bytes("<svg xmlns='http://www.w3.org/2000/svg' width='180' height='48'><rect width='180' height='48' fill='#d9f2f2'/><path d='M20 34 L65 12 L105 30 L155 8' fill='none' stroke='#168c96' stroke-width='3'/></svg>"))],
  caption: [测试图片],
)

#horizontalrule
