// Identification Key PDF Template
// Usage: typst compile --input data='<json>' --input images=false key.typ output.pdf

#let data = json(bytes(sys.inputs.data))
#let show_images = sys.inputs.at("images", default: "false") == "true"

// Page setup
#set page(
  paper: "us-letter",
  margin: (top: 1in, bottom: 1in, left: 0.75in, right: 0.75in),
  header: context {
    if counter(page).get().first() > 1 [
      #set text(size: 9pt, style: "italic", fill: rgb("#666"))
      #data.title #h(1fr) #counter(page).display()
    ]
  },
  footer: [
    #set text(size: 8pt, fill: rgb("#999"))
    gallformers.org/keys/#data.slug #h(1fr) Version #data.version
  ],
)

#set text(size: 11pt)
#set par(leading: 0.65em)

// Title block
#align(center)[
  #text(size: 18pt, weight: "bold")[#data.title]
  #if data.at("subtitle", default: none) != none [
    #v(0.3em)
    #text(size: 12pt, fill: rgb("#666"))[#data.subtitle]
  ]
  #if data.at("authors", default: ()).len() > 0 [
    #v(0.3em)
    #text(size: 10pt)[#data.authors.join(", ")]
  ]
  #if data.at("citation", default: none) != none [
    #v(0.2em)
    #text(size: 9pt, fill: rgb("#666"))[#data.citation]
  ]
]

#v(0.5em)
#line(length: 100%, stroke: 0.5pt + rgb("#ccc"))

#if data.at("description", default: none) != none [
  #v(0.5em)
  #text(size: 10pt, fill: rgb("#444"))[#data.description]
  #v(0.5em)
  #line(length: 100%, stroke: 0.5pt + rgb("#ccc"))
]

#v(1em)

// Letter labels for leads within a couplet
#let lead_letter(index) = {
  let letters = "abcdefghijklmnopqrstuvwxyz"
  letters.at(index)
}

// Render a single lead row: "1a. Text ............ Destination"
#let render_lead(couplet_number, lead, index, is_first) = {
  let prefix = if is_first {
    text(weight: "bold")[#couplet_number#lead_letter(index).]
  } else {
    // Indent subsequent leads to align with first
    context h(measure(text(weight: "bold")[#couplet_number]).width)
    text(weight: "bold")[#lead_letter(index).]
  }

  let dest = lead.destination
  let dest_text = if dest.type == "taxon" {
    emph(dest.name)
  } else {
    text(weight: "bold")[#dest.number]
  }

  // The lead row
  grid(
    columns: (1fr, auto),
    column-gutter: 0.3em,
    [#prefix #h(0.5em) #lead.text #h(0.3em) #box(width: 1fr, repeat[.])],
    dest_text,
  )

  // Notes below the lead (indented, smaller)
  if lead.at("notes", default: none) != none {
    pad(left: 2em)[
      #text(size: 9pt, fill: rgb("#555"), style: "italic")[#lead.notes]
    ]
  }

  // Images below the lead (when enabled)
  if show_images {
    let imgs = lead.at("images", default: ())
    if imgs.len() > 0 {
      pad(left: 2em)[
        #for img in imgs [
          #if "file" in img [
            // Images are served from CDN
            // #image(img.file, width: 40%)
            #text(size: 9pt, fill: rgb("#888"))[\[Image: #img.at("caption", default: img.file)\]]
          ]
        ]
      ]
    }
  }
}

// Sort couplet numbers numerically
#let numbers = data.couplets.keys().sorted(key: k => int(k))

// Render all couplets
#for number in numbers {
  let couplet = data.couplets.at(number)
  block(breakable: false, below: 0.8em)[
    #for (index, lead) in couplet.leads.enumerate() {
      render_lead(number, lead, index, index == 0)
    }
  ]
}
