---
marp: true
theme: default
paginate: false
style: |
  @import url('https://fonts.googleapis.com/css2?family=League+Spartan:wght@300;400;500;600;700;900&display=swap');
  section {
    font-family: 'League Spartan', -apple-system, sans-serif;
    color: #212529;
    font-weight: 400;
    padding: 80px 80px;
  }
  h1 {
    color: #661419;
    font-weight: 900;
    border: none;
    margin-bottom: 0.2em;
  }
  h2 {
    color: #661419;
    font-weight: 600;
    border: none;
  }
  strong { color: #661419; }
  em { color: #585563; font-style: italic; }
  section.cover {
    text-align: center;
    justify-content: center;
    background: linear-gradient(135deg, #661419 0%, #3d0c0f 100%);
    color: white;
    padding: 90px;
  }
  section.cover h1 {
    color: white;
    font-size: 3.2em;
    line-height: 1.1;
    margin-bottom: 0.4em;
  }
  section.cover p {
    color: #c1e0f3;
    font-size: 1.2em;
    font-weight: 300;
  }
  section.bignum {
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    text-align: center;
    background: #c1e0f3;
  }
  section.bignum h1 {
    font-size: 5em;
    color: #661419;
    margin: 0;
    line-height: 1;
  }
  section.bignum p {
    font-size: 1.4em;
    color: #3d0c0f;
    margin-top: 0.5em;
    font-weight: 400;
  }
  section.statement {
    display: flex;
    flex-direction: column;
    justify-content: center;
    padding: 90px 100px;
    border-left: 8px solid #c1e0f3;
  }
  section.statement h1 {
    font-size: 2.6em;
    line-height: 1.2;
    color: #661419;
  }
  section.statement p {
    font-size: 1.3em;
    color: #585563;
    font-weight: 300;
    margin-top: 0.8em;
  }
  section.dark {
    background: linear-gradient(135deg, #661419 0%, #3d0c0f 100%);
    color: white;
    display: flex;
    flex-direction: column;
    justify-content: center;
    padding: 90px 100px;
  }
  section.dark h1 {
    color: white;
    font-size: 2.6em;
    line-height: 1.2;
  }
  section.dark p {
    color: #c1e0f3;
    font-size: 1.3em;
    font-weight: 300;
    margin-top: 0.5em;
  }
  section.dark em {
    color: #bc6428;
    font-style: normal;
    font-weight: 600;
  }
  section.content {
    display: flex;
    flex-direction: column;
    justify-content: center;
    padding: 90px 80px;
    border-top: 6px solid #c1e0f3;
  }
  section.content h1 {
    font-size: 1.8em;
    margin-bottom: 0.6em;
  }
  section.content li {
    font-size: 1.1em;
    margin-bottom: 0.5em;
    line-height: 1.4;
    color: #374151;
  }
  section.content li strong {
    color: #661419;
  }
  section.split {
    display: flex;
    flex-direction: row;
    padding: 0;
  }
  .left-col {
    width: 45%;
    background: linear-gradient(135deg, #661419 0%, #3d0c0f 100%);
    color: white;
    padding: 90px 50px;
    display: flex;
    flex-direction: column;
    justify-content: center;
  }
  .left-col h1 {
    color: white;
    font-size: 2.2em;
    line-height: 1.15;
  }
  .left-col p {
    color: #c1e0f3;
    font-weight: 300;
    font-size: 1.05em;
    margin-top: 0.6em;
  }
  .right-col {
    width: 55%;
    padding: 90px 50px;
    display: flex;
    flex-direction: column;
    justify-content: center;
    background: linear-gradient(180deg, #f0f7fc 0%, #ffffff 100%);
  }
  .right-col li {
    font-size: 1.05em;
    margin-bottom: 0.6em;
    line-height: 1.4;
    color: #374151;
  }
  .right-col li strong {
    color: #661419;
  }
  section.cta {
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    text-align: center;
    padding: 90px 80px;
    background: linear-gradient(180deg, #c1e0f3 0%, #ffffff 40%);
  }
  section.cta h1 {
    font-size: 2.4em;
    margin-bottom: 0.4em;
  }
  section.cta p {
    font-size: 1.15em;
    color: #585563;
    font-weight: 300;
    max-width: 90%;
  }
  section.cta img {
    margin-top: 1em;
  }
  section.hemisphere {
    background-image: url('western-hemisphere.png');
    background-size: auto 60%;
    background-position: right 60px center;
    background-repeat: no-repeat;
    padding: 120px 100px;
    display: flex;
    flex-direction: column;
    justify-content: center;
    background-color: #661419;
  }
  section.hemisphere h1 {
    font-size: 2.4em;
    color: white;
    line-height: 1.2;
  }
  section.hemisphere p {
    font-size: 1.15em;
    color: #c1e0f3;
    font-weight: 300;
    max-width: 55%;
    margin-top: 0.5em;
    line-height: 1.5;
  }
  .accent {
    color: #bc6428;
  }
  .callout {
    text-align: center;
    font-size: 1.6em;
    font-style: italic;
    color: #bc6428;
    font-weight: 600;
    margin-top: 1.2em;
  }
---

<!-- _class: cover -->

![w:550](logo-white.png)

From reference to community.
February 13, 2026

---

<!-- _class: bignum -->

# ~100 → 3,670

We launched in May 2021 with roughly 100 species.
Today: 3,670 gall-forming species across 86 families and 376 genera. 1,455 undescribed taxa. 6,500+ images.

---

<!-- _class: statement -->

# The old tech was holding us back.

Simpler, modern technology. Faster turnaround on features and fixes. After years of being constrained by the old stack, we can move again.

Safer and easier admin tools. Identification keys. Articles. Analytics. All shipped early 2026.

---

<!-- _class: dark -->

# Now we build the community.

The people passionate about galls. The ecological web with galls at its center.

---

<!-- _class: split -->

<div class="left-col">

<h1>Before we grow</h1>

<p>Making the platform safe to move fast on.</p>

</div>
<div class="right-col">

- **Identification keys**, active paper collaboration refining the best key viewer in the field
- **Admin onboarding**, lowering the barrier for new contributors
- **Audit trail**, full tracing of every data change
- **Preview environments** so others can test before we release

</div>

---

<!-- _class: hemisphere -->

# Expand to the entire Western Hemisphere.

Real community support exists for this. We expand our geographic model and rework our maps to encompass the whole hemisphere.

Then we integrate with iNaturalist for things like photos and range data. And we bring DNA barcode data into taxonomy.

---

<!-- _class: split -->

<div class="left-col">

<h1>Gall associates</h1>

<p>The biggest initiative on our roadmap.</p>

<img src="eco-web.png" style="width: 180px; margin-top: 1.5em; opacity: 0.85;" />

</div>
<div class="right-col">

- **Parasitoids, inquilines, nectar-feeding ants, predators**, modeling the full ecological web around each gall
- An enormous area of **active research** with new discoveries constantly
- From documenting individual galls to mapping **ecological networks**

</div>

---

<!-- _class: content -->

# And then

- **New mobile-first ID tool**, usable in the field without connectivity
- **Join the global data ecosystem**, GBIF, DarwinCore, Wikidata, citable DOIs
- **Open contribution pathways**, letting the community feed observations back in

<div class="callout">What are we not seeing?</div>

---

<!-- _class: cta -->

# We need your ideas.

What's missing?
What would make Gallformers more useful for your work?
Would you like to contribute as an admin, a regional expert, help with data entry, something else?

![w:220](feedback-qr.png)

**https://forms.gle/JWLzwnSK6fWdY4z97**
