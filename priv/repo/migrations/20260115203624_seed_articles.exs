defmodule Gallformers.Repo.Migrations.SeedArticles do
  @moduledoc """
  Seeds the articles table with initial reference articles.
  Only runs if the articles table is empty to avoid overwriting future edits.
  """
  use Gallformers.Migration
  import Ecto.Query

  def up do
    # Skip seeding in test environment - tests manage their own data
    if Application.get_env(:gallformers, :env) == :test do
      :ok
    else
      do_seed()
    end
  end

  defp do_seed do
    # Only insert if table is empty
    count = repo().one(from(a in "articles", select: count(a.id)))

    if count == 0 do
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      articles = [
        %{
          slug: "undescribedfaq",
          title: "FAQ About Undescribed Galls",
          author: "Adam Kranz",
          content: content_1(),
          tags: "[\"faq\",\"taxonomy\"]",
          is_published: 1,
          inserted_at: {:placeholder, :now},
          updated_at: {:placeholder, :now}
        },
        %{
          slug: "patrons",
          title: "Gallformers Patrons",
          author: "Adam Kranz",
          content: content_2(),
          tags: "[\"meta\",\"supporters\"]",
          is_published: 1,
          inserted_at: {:placeholder, :now},
          updated_at: {:placeholder, :now}
        },
        %{
          slug: "populusmidgekey",
          title: "Populus Midge Gall Key",
          author: "Adam Kranz",
          content: content_3(),
          tags: "[\"identification\",\"keys\",\"midges\",\"populus\"]",
          is_published: 1,
          inserted_at: {:placeholder, :now},
          updated_at: {:placeholder, :now}
        },
        %{
          slug: "idguide",
          title: "Gall Identification Guide",
          author: "Adam Kranz",
          content: content_4(),
          tags: "[\"identification\",\"guide\"]",
          is_published: 1,
          inserted_at: {:placeholder, :now},
          updated_at: {:placeholder, :now}
        },
        %{
          slug: "vitisgallkey",
          title: "Key to Galls on Grapes (Vitis)",
          author: "Adam Kranz",
          content: content_5(),
          tags: "[\"identification\",\"keys\",\"vitis\"]",
          is_published: 1,
          inserted_at: {:placeholder, :now},
          updated_at: {:placeholder, :now}
        },
        %{
          slug: "contributing",
          title: "Contributing to the Gallformers Reference Library",
          author: "Jeff Clark",
          content: content_6(),
          tags: "[\"meta\",\"contributing\"]",
          is_published: 1,
          inserted_at: {:placeholder, :now},
          updated_at: {:placeholder, :now}
        },
        %{
          slug: "populusaphidkey",
          title: "Populus Aphid Gall Key",
          author: "Adam Kranz",
          content: content_7(),
          tags: "[\"identification\",\"keys\",\"aphids\",\"populus\"]",
          is_published: 1,
          inserted_at: {:placeholder, :now},
          updated_at: {:placeholder, :now}
        }
      ]

      repo().insert_all("articles", articles, placeholders: %{now: now})
    end
  end

  def down do
    slugs = [
      "undescribedfaq",
      "patrons",
      "populusmidgekey",
      "idguide",
      "vitisgallkey",
      "contributing",
      "populusaphidkey"
    ]

    repo().delete_all(from(a in "articles", where: a.slug in ^slugs))
  end

  defp content_1 do
    ~S"""
    # Preface

    At the time of writing, of the 3112 galls listed on the Gallformers database, 1117 are undescribed. That ratio has not changed significantly since the early days of the site and isn't likely to change much in the future. 
    You might reasonably wonder, if a gall can be distinctly identified by its morphology and host plant, such that we can represent it with its own Gallformers entry and consistently apply a Gallformers Code to observations, in what sense is it "undescribed", and what would it take to change that?

    A gall is part of the extended phenotype of the inducing organism, and in many cases the traits of the gall are sufficient to identify the species that induced it. The traits of the gall can often even be used to make an educated guess about what other species the inducer is related to.

    Regardless, the rules of taxonomy dictate that in order to formally describe a new species, taxonomists need to examine a physical specimen of the inducing organism. The species isn't considered "described" until their description is published in a peer-reviewed academic journal (so species described in grad school theses but never published in a journal are still considered undescribed). 

    One of our main goals at Gallformers is to facilitate you, an amateur or academic naturalist, in the process of collecting and rearing such a specimen and getting it to an appropriate taxonomist. 

    Raising an inducer is not hard, but each individual attempt has low odds of success. The biggest reason experts are more likely to succeed is not any particular technique but because they search harder and collect galls in larger numbers than any individual amateur. As a community, we can distribute that effort across many observers. So while you might not be successful yourself, you are still contributing to the process that builds the knowledge we need for someone to eventually succeed. 

    # Being Prepared

    When in the field looking for undescribed galls you need to be prepared if you want to maximize your chances of success in collecting and rearing. Bringing a couple of basic tools with you will greatly improve your odds.

    - Something to cut or cross-section galls. e.g., a small sharp pocket knife. I like pruning shears
    - Containers for collection. Ziploc bags, organza bags, and small plastic vials are each useful for different purposes
    - A way to capture the details of the collection. Ideally a geotagged photograph of the gall, plus a written tag to associate the physical collection with that image and track it going forward

    When you collect a gall it is critically important that you capture several pieces of information. Without this information the specimen can be useless:

    - Date of collection
    - Location of collection: ideally Lat/Long (smart phone cameras often append this information to photographs automatically, but check first to make sure if you plan to rely on this method); if not, at least write down locale info and a rough description of the location so a future observer could find the site
    - Host plant species. If there is any uncertainty, and even if not, it's best to take photos of diagnostic features of the plant that will allow others to confirm your ID. This is especially important if you're in a location you can't conveniently return to

    # So, You Have an Interesting Gall, Now What?

    So if you find a gall you determine to be undescribed (or perhaps a described gall that is of interest for other reasons), what should you do?
    The answer varies significantly depending on the taxon of the inducer. 

    ## 1. Broadly place the taxon of the inducer. 
    Most galls can be placed taxonomically by comparison to other galls using the ID tool. For a truly new, unknown gall, or a gall listed as Unknown on Gallformers, the first step is to figure out what the likely taxon of the inducer is. This can sometimes be done with obvious external features, like rust fruiting bodies or mite erineum, but in general it requires dissection. 

    Carefully cut apart the gall. For most galls, a scalpel is a good tool for this (disposable ones are cheap online); thick-walled or woody galls you'll be better off with pruning shears or a sharper wood-carving knife. Try to make a shallow cut and then pull or pry the gall apart rather than passing the knife through the center of the gall, which destroys the larva. 

    Once you've made the section, photograph both the structure of the gall and the larvae as well as you can. This information should allow us to approximately place the inducer relative to known species.

    ## 2. Determine the gall's development timeline
    Generally speaking, the most difficult part of collecting an inducer specimen is making your collection at the right time. To do that, you need to have a reasonable idea of when the inducer is likely to reach different points of its life cycle. If you find a gall that already has emergence holes, you're either too late or just in time (if the galls are abundant, section one to determine if others may still have inducers within). 

    To help determine when a gall should be collected, I've [created a phenology tool](https://megachile.shinyapps.io/doycalc/) that presents records from the literature and from iNaturalist and extrapolates to latitudes with no data. The records in the tool are incomplete both because existing information hasn't been imported and because it simply doesn't exist yet. Use phenology of apparently-related galls where possible. Otherwise, any information you obtain in collecting and rearing will help improve the tool for future users. 

    There are a few ways to investigate the phenology of a gall, and all of them are valuable even if you don't end up successfully rearing an inducer. 
    If you can conveniently revisit the site, the most informative and least invasive is to simply check the gall at frequent intervals (2x a week is ideal) until you see evidence of emergence, which will give us at least one estimate of its emergence timing. 

    If you aren't likely to see it again, you should collect it immediately and try to rear it (see below). If you succeed, great; if not, then we know to wait a bit longer next time. If you don't want to take it home, or you have a lot of galls in front of you, it's once again informative to cut one open to see what developmental stage the inducer is in. This also lets us better calibrate future collections.

    ## 3. Collect at the right time  
    Once your gall is in the right stage for collection (pupae or adults; sometimes large larvae), depending on the taxon, you can either collect the sample directly or take the gall off the plant and bring it home to complete maturation. When removing the gall from the plant, it's often wise to collect not just the gall but the general area of the plant the gall is on, like stem sections above and below a stem gall or the full leaf or even twig for a leaf gall. 

    In every case, collecting more specimens is better for science and generally (but not necessarily or universally--use your discretion) not a threat to populations.

    In a Pucciniales rust or an eriophyid mite gall, #2 is where the tricky part ends: if you collect the gall at the right time (when it is sporulating for a rust, when it is fresh for a mite gall), you just need to dry it and store it in an envelope. 

    For other taxa, like aphids, midges, or wasps, collections can't be made until after the point when the inducer no longer relies on the plant to complete its maturation. This happens at different life stages for different inducing taxa, but there are some general patterns. 

    Hemipteran inducers like aphids, phylloxera, and psyllids exist as nymphs for much of the gall's growth, and eventually produce winged adults at maturation. These winged adults are the ones necessary for description, and they typically hang out in the gall for some time before leaving through an opening called an ostiole. These can be collected directly from the gall as adults and preserved (see below).

    Cynipid wasps exist as larvae for most of the gall's growth, and if the gall is collected in the larval stage they will likely die rather than emerge. Once they begin to pupate, however, they no longer need to feed on the gall and will likely survive to emerge from pupation and chew their way out of the gall. 

    Cecidomyiid midges exist as larvae in the gall and either pupate in the gall or emerge as a larva and pupate in the soil. The appropriate time to collect may vary by species for this group.

    ## 4. Bring the gall home to rear
    Now that you've collected the gall, you need to store it in a sealed container so that whatever emerges won't escape. For spring galls on fresh, succulent, tissue, these need to be watertight so that the gall doesn't dry out. These will likely emerge within a relatively short timespan, so mold is often not a fatal issue. Ziplocs are a good choice but jars also work. Don't worry about air holes; inducers are small and don't use much oxygen before they emerge. Agamic cynipini or other detachable overwintering galls need to be kept humid but not too much so. Try to replicate the conditions they might experience overwintering outdoors in the leaf litter to the extent possible. We have had success for some galls with simple mesh bags indoors, however. Note that the emergence may be within a day or less of collection, but it may also take more than two years. If nothing has emerged yet, that may mean it's just waiting for the right moment.

    For cecidomyiid midges, the process can be more involved. See [this post by Charley Eiseman](https://bugtracks.wordpress.com/rearing/) for more information, but you may need to transfer the larva/pupae from the gall container into soil and potentially refrigerate it over the winter before an adult can emerge.

    ## 5. Preserve what you reared
    Once you have a specimen in hand, you need to preserve it to make sure your hard work doesn't go to waste through rot or degradation. The primary concern here is water: DNA-destroying enzymes are only functional when water is present. Water can be removed either by storing the specimen in a low-humidity environment like a freezer, or using a high-proof ethanol. Low proof ethanol (70%) is not ideal because it contains substantial proportion of water; 95% is great. 

    For eriophyid mite and rust galls, preservation means drying the tissue and storing it in a paper envelope. 

    For other arthropods, adults should be killed in a freezer and stored there dry until they can be mailed to a taxonomist. To ship the specimens, pack with cotton or tissue to prevent them from being damaged by rattling around the container. The galls from which these arthropods emerged should be preserved as well if possible--in many cases they can also simply be dried; if they are especially succulent or fleshy, they are likely no longer worth preserving by the time the adult emerges.

    Some small specimens are prone to collapse or shrivel if dried. These can be better preserved in ethanol, but it must be high proof (95%). If you do choose to use ethanol, note that it dissolves both pen ink and graphite, and care must be taken to avoid smearing labels. A key concern is ensuring that the specimen can always be associated with its collection information, so making sure the label remains legible is crucial. Ideally, labels should be printed on a printer rather than written with pen or pencil, but if you do use pen or pencil, make sure the alcohol is sealed properly and the writing will not be in contact with it. 

    ## 5.5 Inquilines
    Unfortunately, it's as likely as not that you've gone through this whole process and ended up with something that isn't the inducer specimen needed to describe the gall. Depending on the gall, the adult arthropod emerging from your gall may be vastly more likely to be another species that displaced the inducer. Luckily these are also of scientific interest and can be preserved the same way. This is another reason rearing an inducer often takes many attempts.

    ## 6. Mail your specimens to a taxonomist
    [Contact the Gallformers team](mailto:gallformers@gmail.com) and we will do our best to help you network with someone who can describe your specimen. We have contacts working on most groups, with the conspicuous exception of eriophyid mites, which seem to be underserved taxonomically right now.
    """
  end

  defp content_2 do
    ~S"""
    Thank you to all our Patrons!

    # Oak tier:

    - Madeleine Doney
    - Joshua Newbend

    # Cecidomyiid tier:

    - Timothy Frey
    - Kathleen Sweetman

    # Cynipid tier:

    - Andrew Deans
    - Leslie Flint
    - Ellen Martinson
    - Dale Ball

    # Eriophyid tier:

    - Mark Apgar
    - Lisa Appelbaum
    - Deborah Barber
    - Bird Bird
    - Tricia Bippus
    - Mimi Brown
    - Andrew Cameron
    - Catherine Chang
    - Ruta Daugavietis
    - Andrew Forbes
    - Jennifer Flynn
    - G Froelich
    - Chris Friesen
    - Michael Gates
    - Bert Harris
    - Sara Ruth Harrison
    - Noriko Ito
    - Henrik Kibak
    - Joseph L
    - Karlyn Lewis
    - Moe Morelock
    - Maureen Murphy
    - Robert Riedl
    - ribbon
    - cassi saari
    - Carrie Seltzer
    - Ramsey Sullivan
    - Scott Ulian
    - Linyi Zhang
    - Miles Zhang
    """
  end

  defp content_3 do
    ~S"""
    This key is largely based on original categorizations of iNaturalist observations, with some remarks on the limited prior literature. Even moreso than many gall-inducer taxa, midge galls on native North American poplars seem to map very closely onto midges known from Europe; these similarities are noted below. 

    ## The Key

    1. Leaf edge roll: [Prodiplosis morrisi](https://www.gallformers.org/gall/2166) (can be confused with [Aceria dispar](https://www.gallformers.org/gall/4004), which causes ragged leaf edge rolling but also shortens the petiole and occurs in bunched clusters)
    2. Concentric circular spot with raised papilla and exposed larva below
    1. A green spot on Populus balsamifera: [p-balsamifera-leaf-gall](https://www.gallformers.org/gall/3987)
    2. A green spot on Populus tristis (= trichocarpa): [p-tristis-leaf-spot](https://www.gallformers.org/gall/4027) (this and the previous are indistinguishable without host ID and may be sympatric where the hosts both occur. They may be conspecific.)
    3. A reddish blister on Populus grandidentata: [?Harmandiola stebbinsae](https://www.gallformers.org/gall/3985) (It’s ambiguous whether H stebbinsae fits in this group. Gagne 1989’s drawing matches this description, but no observations of this gall type have been reported from the host or range given for that species. It also seems unlikely that none of the sources would note that the gall has an exposed larva if it did. The text descriptions suggest something like [p-tremuloides-like-globuli](https://www.gallformers.org/gall/4033) but that gall looks very different from Gagne’s drawing. No galls matching this description have been observed on Populus grandidentata so far.)
    3. Larva concealed within galled tissue, protruding at least slightly at least one side of the leaf
     1. Gall entirely on the upper side of the leaf, with only a flat opening on the lower side
        1. A relatively large, spherical, thick-walled pea gall on a leaf vein: [p-tremuloides-like-tremulae](https://www.gallformers.org/gall/4028) (Similar to [Harmandiola tremulae](https://bladmineerders.nl/parasites/animalia/arthropoda/insecta/diptera/nematocera/cecidomyiidae/cecidomyiinae/cecidomyiidi/cecidomyiidi-unplaced/harmandiola/harmandiola-tremulae/) in Europe. [Russo’s species B](https://www.gallformers.org/gall/3999) might key here but it has an opening above.)
        2. A relatively small, capsule-shaped, thin-walled gall anywhere on the upper leaf: [p-tremuloides-like-globuli](https://www.gallformers.org/gall/4033) (Similar to [Harmandiola globuli](https://bladmineerders.nl/parasites/animalia/arthropoda/insecta/diptera/nematocera/cecidomyiidae/cecidomyiinae/cecidomyiidi/cecidomyiidi-unplaced/harmandiola/harmandiola-globuli/) in Europe. Easily confused with [H helena](https://www.gallformers.org/gall/4005) from above)
     2. Gall largely on the lower side or evenly protruding from both sides
        1. Circular to ovate openings typically on the upper side but sometimes on the lower or even on both sides of the leaf. 
            1. Circles often visible before inducers emerge. Gall protruding more or less but typically to the same degree on either side of the leaf. Variable in size, shape, and number but often confluent with each other and with nearby veins, glossy and succulent, often but not always clustering in large confluent masses at the leaf base though never on the petiole: [p-tremuloides-like-populnea](https://www.gallformers.org/gall/4030) (Similar to [Lasioptera populnea](https://bladmineerders.nl/parasites/animalia/arthropoda/insecta/diptera/nematocera/cecidomyiidae/cecidomyiinae/lasiopteridi/lasiopterini/lasioptera/lasioptera-populnea/)/Contarinia populi in Europe. Galls with confluent and thus linear/elongated slits can be confused with [p-tremuloides-lips-gall](https://www.gallformers.org/gall/4029). Seems to be Russo’s sp A. His [species B](https://www.gallformers.org/gall/3999) might key here as well but I haven’t seen anything matching that description yet. This is a highly variable gall and is perhaps the morphotype most likely to represent multiple species?)
        2. Linear slit openings on one or the other side of the leaf
            1. Linear slits on the lower side of the leaf (based on Gagne’s drawing; opposite of the original Felt description) 
                1. Numerous small globular galls in loose rows along the midrib, protruding equally on both sides of the leaf, with a hole on the lower side: [Harmandiola helena](https://www.gallformers.org/gall/4005) (Similar to [Harmandiola pustulans](https://bladmineerders.nl/parasites/animalia/arthropoda/insecta/diptera/nematocera/cecidomyiidae/cecidomyiinae/cecidomyiidi/cecidomyiidi-unplaced/harmandiola/harmandiola-pustulans/) in Europe. Easily confused with [p-tremuloides-like-globuli](https://www.gallformers.org/gall/4033) from above. All of my IDs of H helena are made based on Gagne’s figure, which is listed as “possibly helena,” contradicts the original description, and are essentially all on Populus grandidentata rather than the type host, Populus tremuloides.)
                2. Pocked, globular galls with a hairy slit on the lower side. Apparently unique in having globular galls that expand toward the base: [Russo’s species C](https://www.gallformers.org/gall/4000) 
            2. Linear slits on the upper side of the leaf
                1. Small, numerous, thin-walled pouch galls in rows on either side of the midrib or lateral veins, only a small protrusion if any on the upper side around the opening: [p-tremuloides-pouch-gall](https://www.gallformers.org/gall/4031) (Similar to [Harmandiola populi](https://bladmineerders.nl/parasites/animalia/arthropoda/insecta/diptera/nematocera/cecidomyiidae/cecidomyiinae/cecidomyiidi/cecidomyiidi-unplaced/harmandiola/harmandiola-populi/) in Europe)
                2. Large, thick-walled, globular galls singly or in clusters on the lamina, often with wide succulent lips protruding slightly on the upper side of the leaf: [p-tremuloides-lips-gall](https://www.gallformers.org/gall/4029) (Similar to [Harmandiola cavernosa](https://bladmineerders.nl/parasites/animalia/arthropoda/insecta/diptera/nematocera/cecidomyiidae/cecidomyiinae/cecidomyiidi/cecidomyiidi-unplaced/harmandiola/harmandiola-cavernosa/) in Europe. Can be confused with galls of [p-tremuloides-like-populnea](https://www.gallformers.org/gall/4030) with confluent, elongate openings on the upper side)
    """
  end

  defp content_4 do
    ~S"""
    A gall is a novel organ grown by a plant when another organism alters the way the plant expresses its genes. Gall-inducers are found in a wide range of taxa. Insects, mites, and fungi are the most common, but nematodes, bacteria, and even plants can also induce galls.

    Because gall induction is a biochemical alteration of the growth pattern of a plant, galls are highly targeted, usually specific to a single part of one or several closely related{' '} host species. Some gall-inducing species form distinct galls on different hosts or, in different portions of their lifecycle, on different parts of the same host. These galls are listed separately in the database.

    Galls typically have unique, recognizable exterior features that are distinct from galls formed by their close relatives. This means that identifying a gall-inducer to species requires no taxon-specific anatomical knowledge and is generally much easier than identifying other fungi or arthropods.

    Galls are created to feed and protect their inducers, and these conditions are attractive to other organisms. Many galls are targeted by predators, parasitoids, and inquilines that live within the gall, some of which do not harm the gall-inducer. In most cases this database does not include these organisms, but a few inquilines modify developing galls and create distinct galls, and in these cases the gall is listed as a separate entry in the database.

    ## Using our ID tool

    The most important step in gall ID is the correct identification of the host plant. If you’re not sure what your plant is, you can take a photo and make an observation on iNaturalist. The site’s computer vision algorithm will give you a plausible suggestion, which you can confirm yourself with other resources and will likely be confirmed or corrected by other users. There are many plant ID resources available online:

    - [New England](https://gobotany.nativeplanttrust.org/advanced/)
    - [Michigan](https://michiganflora.net/)
    - [North America](http://efloras.org/flora_page.aspx?flora_id=1)
    - [California (willows only)](http://tchester.org/plants/analysis/salix/key.html#picture)

    For plants with few galls, host ID alone will likely filter the possibilities enough that your gall is recognizable. However, most galls are found on plant species with many galls. In those cases, select additional traits, starting with location and detachable, until the results are manageable. See the gall{' '} filter term guide for more info on what these selections mean.

    Once you find a plausible set of options, you may want to confirm your ID by checking the original descriptions of the gall, available on its page. Additional information about taxonomic shifts and ID tips is also available on each gall page.

    Be aware that this database is a work in progress and many galls may not be added yet. The database is complete for plants and galls marked as such. However, many gall-inducing species are not yet described, and if you find a gall that is not listed on a host that is marked complete, please contact us at gallformers@gmail.com.

    ## ID Tips and Troubleshooting

    If you’re not finding a match, try using only host, location, and detachable before you give up. Common issues using these filters include

    - Wrong host ID (try moving up to the genus level or checking your second or third guesses)
    - Host not included in the database. Many hybrids or rare species, especially among highly speciose host groups like oaks or goldenrods, may not appear in the database at all or may not have comprehensive gall associations. Try searching a close relative or hybrid parent instead, or the section for Quercus or Carya.
    - Whether a gall is “Between veins” or “on leaf veins” can occasionally be ambiguous or misleading; try choosing the opposite or avoiding these terms entirely
    - Bud galls are often mistaken for stem galls
    - Acorn galls on red oaks can be mistaken for bud galls (red-group oaks have small overwintering acorns with similar size and placement as their buds)
    - A gall looks detachable but is not (or vice versa); check the results for the opposite option
    - If your gall is only found on the leaf midrib, it may be a species that could theoretically be found on any of the leaf veins; check “on leaf veins” instead
    - Gall-inducers, especially cynipid wasps, occasionally form galls on the opposite side of the leaf from their normal habit; check the results for the opposite option
    - Wrong season selected. Galls often persist long after their season of appearance. Only use this filter if the gall is obviously fresh

    Generally speaking, it’s a good idea to try sequentially removing filters to make sure you’re not missing relevant possibilities.

    Other traits, including color, walls, cells, alignment, shape, and texture, may not be added comprehensively or at all. Check the gall filter term guide to make sure you’re applying the terms consistently with our usage.

    Note that if you search by host at the section or genus level, you are likely to encounter galls from other parts of the country than your observation. Be sure to confirm the range makes sense before making an ID.
    """
  end

  defp content_5 do
    ~S"""
    ## The Key

    1. Integral
    1. On main stem, a slight swelling typically directly adjacent to a node. Contains beetle larva and frass: [Ampeloglypter sesostris](https://www.gallformers.org/gall/3111)
    2. Swollen buds containing gall midge larvae: [Contarinia johnsoni](https://www.gallformers.org/gall/3109)
    3. On petiole or tendrils; tapered swellings with matte green exterior when fresh, brown and often splitting longitudinally with age: [Neolasioptera vitinea](https://www.gallformers.org/gall/1408)
    4. On leaves, petioles, inflorescences, and tendrils; abrupt swellings, either densely clustered across many tissues or scattered in globules on leaves, exterior pink-red, succulent and glossy, developing small egress holes on the upper side later in the season: [Vitisiella brevicauda](https://www.gallformers.org/gall/1407)
    5. Exclusively on leaves
        1. Blistering above with corresponding patches of white, red, or brown erineum below: [Colomerus vitis](https://www.gallformers.org/gall/689)
        2. Numerous globular pockets on the lower side of the leaf with hairy tufts above. Extremely common: [Daktulosphaira vitifoliae](https://www.gallformers.org/gall/1406)
        3. Broad, flat, light yellow-green swellings on both sides of the leaf, thick-walled in spring but hollow with large opening holes by early summer: [Heliozela aesella](https://www.gallformers.org/gall/1419)
        4. Many small globular swellings, often pink-red and succulent and resembling Vitisiella brevicauda but differing in the presence of
            1. a tuft or covering of hairs. Highly variable; may represent multiple species: [Vitisiella vitis-tuft-gall](https://www.gallformers.org/gall/2687)
            2. a narrow, hairy, sometimes curved protrusion on the lower side: [Dasineura v-cinerea-hook-gall](https://www.gallformers.org/gall/1748)
    2. Detachable
    1. On stem at nodes (replacing buds)
        1. One (sometimes several) large, globular, polythalamous gall(s). May be hairy or glabrous, ribbed or smooth: [Ampelomyia vitispomum](https://www.gallformers.org/gall/1405)
        2. A cluster of typically 10 or more pointed-globular monothalamous galls. May be hairy or glabrous: [Ampelomyia vitiscoryloides](https://www.gallformers.org/gall/1404)
    2. On leaves
        1. Numerous elongate, conical galls scattered on either the upper or lower side of the leaf (typically not both). Yellow, turning red with exposure to the sun. May be hairy or glabrous: [Ampelomyia viticola](https://www.gallformers.org/gall/1403)
            1. Nearly identical galls on Vitis tilifolia in Mexico may or may not be a distinct species: [Ampelomyia v-tiliifolia-pubescent-conical-gall](https://www.gallformers.org/gall/3355)
        2. Numerous abruptly truncated cylindrical hairless yellow galls scattered on the lower side of the leaf. Common on Vitis mustangensis but similar galls have been observed on other Vitis species: [Ampelomyia v-mustangensis-lower-tube-gall](https://www.gallformers.org/gall/1357)
        3. One or two wide ovate-conical galls causing a bunching of leaf tissue beyond the location of the gall. Green, turning red in the sun. May be hairy or glabrous. [Ampelomyia vitis-large-cone-gall](https://www.gallformers.org/gall/2265)
    """
  end

  defp content_6 do
    ~S"""
    If you would like to contribute to the Gallformers Reference Library it is quite easy. This article will describe the type of articles that we are looking for as well as the steps needed to get your article published.

    ## Types of Reference Material We Publish

    We are primarily interested in publishing articles about galls. The types of content that we are currently looking for are:

    - Guides to rearing adults from galls
    - Beginners guide to finding galls
    - Guides for host identifications
    - Keys for complex groups
    - Any original gall related research or findings

    ## Understanding How Your Article Will Be Licensed

    Currently all original content that is published on the site is released under a [Creative Commons 4.0 Attribution License](https://creativecommons.org/licenses/by/4.0/). Attribution will refer to gallformers generally but most folks citing information want to give credit where credit is due and will include the specific author.

    If you want to publish an article under a different license, [get in touch with us](mailto:gallformers@gmail.com) and we will see what we can do.

    ## Writing Your Article and Getting it Published

    First you will need 2 things:

    1. A [Github](https://github.com/) account
    1. An understanding of [Markdown](https://www.markdownguide.org/getting-started)

    ### Writing

    With these two steps complete you are ready to write! Write your article in whatever editor you choose. It is helpful, but not necessary, to use an editor that is markdown aware. You can also write it in another format, like MS Word or Google Docs, and then use one of the many online tools that will covert that format to markdown. Generally it is a good idea to stick to simple markdown as some of the various extensions to markdown will likely not render properly. If you are looking for a basic template you can view [this article's markdown source](https://github.com/jeffdc/gallformers/blob/main/ref/contributing.md).

    #### Required Metadata

    At the top of your article you must create a required metadata section that will contain the title, publishing date, author, and other info. I suggest copying this from this [article's source](https://github.com/jeffdc/gallformers/blob/main/ref/contributing.md). The metadata section must look like this:
    ```
    ---
    title: 'The Title of Your Awesome Article'
    date: '2022-02-27'
    description: 'A short one sentence description of this article.'
    author:
    name: Your Name
    ---
    ```

    #### Limitations

    Currently it is not possible to add hosted images to the article. You can link to images that are already published on the web, but please use this sparingly. We will eventually have the ability to publish images along with articles.

    ### Publishing

    To get your article published you will open a Pull Request against the gallformers repository on Github. To do this, follow these steps:

    1. Navigate to the [gallformers repository](https://github.com/jeffdc/gallformers) on Github
    1. Make sure that you are logged in to Github
    1. Click on the "Add File" button
    1. Select "Create a New File"
    1. This will create a fork of the repository under your account and allow you to open a pull request
    1. Name your file. This should be a short but descriptive title for your article. Please use all lowercase letters with no spaces or punctuation
    1. Copy the source of your article and paste it into the "Edit New File" box
    1. Click "Propose New File" at the bottom of the page
    1. On the next screen click on "Create pull request"
    1. In the comment section write any details that you want. These will seen by the reviewer and might be useful to describe why you think the article should be published on Gallformers
    1. Click on "Create pull request"

    At this point a Pull Request has been created. One of our reviewers will review the article. We may request changes to the article. We will do this via Github's review mechanism. You will be notified by email so make sure you have added Github to your address book so the messages do not end up lost in your spam folder.

    Once the review process is done the article will go live on the site within a couple of hours.

    ### Future Edits

    If for whatever reason in the future you want to update the article the process is straight-forward. 

    1. Navigate to the article on Github. They are all in the [`ref`](https://github.com/jeffdc/gallformers/tree/main/ref) directory 1. Once you have clicked on the article you want to edit, find the pencil icon in the toolbar above the article content and click on it
    1. This will take you into an editor where you can make the changes
    1. Once the changes are complete fill in a comment as to the nature of the changes that you made
    1. Click on "Propose Changes"
    1. On the next screen click on "Create pull request"

    This will then trigger the review process which is the same as with the Publish step above.

    ## Closing Thoughts

    We thank you for the articles that you write. The gallformers site would not exist without the hundreds of hours of volunteer time from our band of gall nerds.
    """
  end

  defp content_7 do
    ~S"""
    *This key is a synthesis of gall descriptions given in the literature. There is reason to believe that these gall descriptions may not map perfectly onto monophyletic aphid taxa; cases where this is known to be true will be noted but the full extent of variation for all species is likely not known, and cryptic species likely await description.*

    ## Table of Contents

    1. [Populus Sections](#populus-sections)
    2. [Notes](#notes)
    3. [The Key](#the-key)
    - [1. Leaves folded into loose “nest.”](#1-leaves-folded-into-loose-nest)
    - [2. Gall on stem, dropping late in the season leaving a flat circular scar](#2-gall-on-stem-dropping-late-in-the-season-leaving-a-flat-circular-scar)
    - [3. Full or most of leaf galls](#3-full-or-most-of-leaf-galls)
    - [4. Pouch or pocket galls on leaf](#4-pouch-or-pocket-galls-on-leaf)
    - [5. Globular to conical galls on petiole at or below leaf base](#5-globular-to-conical-galls-on-petiole-at-or-below-leaf-base)

    ## Populus Sections

    | **Section**     | **Species**                                                   |
    |-----------------|---------------------------------------------------------------|
    | **Aigeiros**    | *deltoides*, *fremontii*, *nigra*                             |
    | **Populus**     | *alba*, *tremula*, *tremuloides*, *grandidentata*              |
    | **Tacamahaca**  | *angustifolia*, *balsamifera*, *tristis* (= *trichocarpa*)    |

    ## Notes

    > **Note:** *Populus tremula*, *alba*, and *nigra* are non-native species found in cultivated settings.

    > **Caution:** Some galls may require DNA or anatomical evidence to distinguish between closely related species.

    ## The Key

    ### 1. Leaves folded into loose “nest.”

    No galled tissue, leaves often not even curled, aphids exposed along the petioles causing them to shorten and bend together. Only on *Populus tremuloides*:

    [Pachypappa rosettei](https://www.gallformers.org/gall/4012)

    ---

    ### 2. Gall on stem, dropping late in the season leaving a flat circular scar

    Slit opening usually aligned with stem rather than perpendicular to it. On Sect. Tacamahaca and Aigeiros:

    [Pemphigus populiramulorum](https://www.gallformers.org/gall/3459)

    ---

    ### 3. Full or most of leaf galls

    <details>
    <summary>Expand for details</summary>

    1. **Galling of all or part of leaf**

     <details>
       <summary>Expand for options</summary>
       
       - **Entire leaf with walnut-like corrugations**  
         Wax-glossy, only on *Populus deltoides*:
         [Mordwilkoja vagabunda](https://www.gallformers.org/gall/3678)
       
       - **Large, broadly wrinkled sacks**  
         Dull in texture, only on *Populus tremuloides*:
         [Pachypappa sacculi](https://www.gallformers.org/gall/4013)
     </details>

    2. **No galling, leaf folded to varying extents**

     <details>
       <summary>Expand for options</summary>
       
       - **Tight folding, blistering, or convolution**
         
         <details>
           <summary>Expand for specifics</summary>
           
           - **Native poplars**:  
             [Thecabius gravicornis](https://www.gallformers.org/gall/4010)  
             [Thecabius populiconduplifolius](https://www.gallformers.org/gall/4034)
           
           - **Non-native poplars**:  
             [Thecabius lysimachiae](https://www.gallformers.org/gall/4011)  
             [Thecabius affinis](https://www.gallformers.org/gall/3989)
         </details>
       
       - **Loose bending at midrib without discoloration**  
         [Pachypappa pseudobyrsa](https://www.gallformers.org/gall/3677)
     </details>

    </details>

    ---

    ### 4. Pouch or pocket galls on leaf

    <details>
    <summary>Expand for details</summary>

    1. **Leaf edge fold**

     <details>
       <summary>Expand for options</summary>
       
       - **A thick, crescent shaped gall containing many aphids.**  
         On *Populus angustifolia*:
         [Cornaphis populi](https://www.gallformers.org/gall/4057)
       
       - **A globular, near spherical, pouch bulging out of a leaf edge fold.**  
         On *Populus tremuloides*:
         [p-tremuloides-cherry-gall](https://www.gallformers.org/gall/4058)  
         *(only tentatively thought to be induced by an aphid)*
       
       - **A simple ungalled leaf edge fold**
         
         <details>
           <summary>Expand for specifics</summary>
           
           - On *Populus deltoides* or *balsamifera*: stem mother  
             [Thecabius populiconduplifolius](https://www.gallformers.org/gall/4034)  
             *(some sources state this is also known from *Populus nigra* but these reports may be *T. affinis*; broadly this seems to be a native species found on native hosts)*
           
           - On *Populus nigra*: stem mother  
             [Thecabius affinis](https://www.gallformers.org/gall/3989)  
             *(a European species present in NA but likely only found on non-native *Populus* like *P. nigra*; similar observations on native poplars are presumably *T. populiconduplifolius*. The species are closely related but have different chromosome counts.)*
         </details>
       
     </details>

    2. **Linear or ovate pocket(s) on lamina or along edge, often parallel to midrib**

     <details>
       <summary>Expand for options</summary>
       
       - **Large, smooth, flat-sided cockscomb gall.**  
         On *Populus deltoides*:
         [Pemphigus longicornis](https://www.gallformers.org/gall/3451)
       
       - **Pseudogall pocket/pouch**
         
         <details>
           <summary>Expand for specifics</summary>
           
           - **A single long, narrow, pseudogall parallel to the midrib, barely raised above the leaf, containing one apterous aphid.**  
             In spring. Typically on Sect. Tacamahaca; apparently the same species on *Populus fremontii*: stem mother  
             [Thecabius populimonilis](https://www.gallformers.org/gall/4009)
           
           - **Apparently similar, on Sect. Tacamahaca:** stem mother  
             [Thecabius gravicornis](https://www.gallformers.org/gall/4010)  
             *(disagreement in the literature whether this is on the midrib, adjacent to the midrib, or halfway between the midrib and the leaf edge)*
           
           - **One to four rows of bead-like galls parallel to midrib or (on *Populus fremontii*) along the edge of the leaf, each containing a single winged or apterous aphid.**  
             In summer. Often in numbers, overtaking the whole leaf and causing it to spiral. Typically on Sect. Tacamahaca.  
             Apparently the same species forms similar galls on *Populus fremontii* but this may be worth confirming:  
             [Thecabius populimonilis](https://www.gallformers.org/gall/4009)
         </details>
       
       - **Pseudogall pocket on midrib.**  
         Typically on *Populus deltoides*: stem mother  
         [Pachypappa pseudobyrsa](https://www.gallformers.org/gall/3677)
       
       - **Gall on midrib**  
         *(many of these aphids occur on the same hosts and cause similar or overlapping symptoms; DNA or anatomical evidence is likely necessary to distinguish them)*
         
         <details>
           <summary>Expand for specifics</summary>
           
           1. **Lower midrib**
              
              <details>
                <summary>Expand for options</summary>
                
                - **An elongate-globular or triangular pocket gall, typically near the base of the leaf.**  
                  Only on Sect. Tacamahaca:
                  [Pemphigus betae](https://www.gallformers.org/gall/3461)
                
                - **Similar, only known from *Populus angustifolia* in Utah:**  
                  [Pemphigus knowltoni](https://www.gallformers.org/gall/3462)
                
                - **Similar, typically found on the upper leaf per early lit but Foottit et al 2010 state that this aphid was found predominantly in galls on the lower side. A third, undescribed taxon was also reported on similar galls:**  
                  [Pemphigus populivenae](https://www.gallformers.org/gall/3456)
                
                - **Irregularly globular, twisted galls on the lower midrib, opening with a thick slit on the upper midrib.**  
                  On *Populus fremontii*:
                  [Pemphigus p-fremontii-midrib-gall](https://www.gallformers.org/gall/3996)
              </details>
           
           2. **Upper midrib**  
              *(these three galls all occur chiefly on Sect. Tacamahaca and their galls may overlap morphologically especially when populations are high)*
              
              <details>
                <summary>Expand for options</summary>
                
                1. **Localized at the base of the leaf**
                   
                   <details>
                     <summary>Expand for specifics</summary>
                     
                     - **A single or sometimes two large irregularly globose galls. Narrow to a small thickening of the midrib where they connect to the leaf base.**  
                       Alate aphids emerge in mid-July. Only on Sect. Tacamahaca:  
                       [Pemphigus populiglobuli](https://www.gallformers.org/gall/3458)
                   </details>
                
                2. **Along the length of the leaf**
                   
                   <details>
                     <summary>Expand for specifics</summary>
                     
                     - **Leathery, slightly sinuous thickening of the midrib with sometimes one but typically at least 2 globular galls, often confluent in irregular cockscomb divided by saddle-like furrows, typically with a roughened surface.**  
                       Alate aphids emerge in late August-September. Only on Sect. Tacamahaca:  
                       [Pemphigus monophagus](https://www.gallformers.org/gall/3457)
                     
                     - **An elongate-globular or triangular pocket gall, typically near the base of the leaf.**  
                       Typically on Sect. Tacamahaca:  
                       [Pemphigus populivenae](https://www.gallformers.org/gall/3456)
                   </details>
                
              </details>
           
           3. **Clusters of yellow-red globular galls on the lower side of the leaf of *Populus tremuloides***  
              [Pemphigus rileyi](https://www.gallformers.org/gall/3990)  
              *(unclear if this is in fact an aphid species; no sources mention the aphid past Stebbins)*
         </details>
       
     </details>

    </details>

    ---

    ### 5. Globular to conical galls on petiole at or below leaf base

    <details>
    <summary>Expand for details</summary>

    1. **Not twisted (occasionally bending the petiole), not incorporating any leaf tissue**

     <details>
       <summary>Expand for options</summary>
       
       - **Opening with a round ostiole. Conical, often squatly triangular but sometimes elongate and narrow.**  
         Only on *Populus nigra var italica*:
         [Pemphigus bursarius](https://www.gallformers.org/gall/3450)  
         *(reported from North America in the literature but apparently not observed on iNaturalist yet?)*
       
       - **Opening with a simple linear slit, sometimes with protruding lips**
         
         <details>
           <summary>Expand for specifics</summary>
           
           - **Slit oriented parallel to petiole, a stem gall rarely found on only petiole:**  
             [Pemphigus populiramulorum](https://www.gallformers.org/gall/3459)
           
           - **Slit oriented nearly perpendicular to petiole**
             
             <details>
               <summary>Expand for specifics</summary>
               
               - **Globular (some galls in CA almost laterally compressed), near junction with leaf (though not incorporating leaf midrib), slit has protruding, sometimes almost conical, lips. May cause petiole to bend slightly but never twist.**  
                 Aphids in galls from May to October (longer in CA?). On *Populus fremontii* and *deltoides*:  
                 [Pemphigus obesinymphae](https://www.gallformers.org/gall/3453)  
                 *(eastern galls of this species were formerly considered a morph of *P. populitransversus*)*
               
               - **Elongate, near center of petiole, opens via slit.**  
                 Aphids in galls from March to July. On *Populus deltoides* only:  
                 [Pemphigus populitransversus](https://www.gallformers.org/gall/3460)
             </details>
           
         </details>
       
     </details>

    2. **Twisted, with a long winding groove or slit (which may or may not ever open), gall sometimes including base of midrib**

     <details>
       <summary>Expand for options</summary>
       
       - **Only at junction of petiole and leaf**  
         *(these aphids apparently have at least some host overlap and cause nearly indistinguishable symptoms; DNA or anatomical evidence is likely necessary to distinguish them)*
         
         <details>
           <summary>Expand for specifics</summary>
           
           1. **Almost entirely above upper surface of leaf; on Sect. Tacamahaca**
              
              - **A single or sometimes two large irregularly globose galls. Narrow to a small thickening of the midrib where they connect to the leaf base.**  
                Alate aphids emerge in mid-July. Only on Sect. Tacamahaca:  
                [Pemphigus populiglobuli](https://www.gallformers.org/gall/3458)
           
           2. **To either side of the leaf; on Sect. Aigeiros**
              
              <details>
                <summary>Expand for options</summary>
                
                - **Large, near leaf base but almost entirely on petiole. Opening with a slit.**  
                  On *Populus deltoides* and *fremontii*:  
                  [Pemphigus nortonii](https://www.gallformers.org/gall/3452)  
                  *(Russo notes that uncited DNA evidence suggests the CA galls that key to this species are more closely related to *populiramulorum*; this key leaves them together pending further information)*
                
                - **Galls with a visible exit hole or fully on the leaf lamina can be identified as *populicaulis*; those with no hole and found equally on the petiole are apparently indistinguishable from *tartareus*.**  
                  On leaf base with some of the petiole twisted into the gall. On *Populus deltoides*  
                  [Pemphigus populicaulis](https://www.gallformers.org/gall/3454)
                
                - **Principally on the petiole but with enough of the gall on the blade that the leaf margin can be traced along the edge.**  
                  On *Populus deltoides*:  
                  [Pemphigus tartareus](https://www.gallformers.org/gall/4014)
              </details>
           
         </details>
       
       - **Typically below junction of leaf along the petiole, though some galls may be near the junction**
          
          - **Twisted petioles maturing to large, irregularly globular, rough-textured galls.**  
            Only on *Populus nigra var italica*:  
            [Pemphigus spyrothecae](https://www.gallformers.org/gall/3994)
       
     </details>

    </details>

    ---
    """
  end
end
