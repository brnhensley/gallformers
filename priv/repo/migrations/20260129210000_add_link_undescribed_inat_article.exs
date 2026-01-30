defmodule Gallformers.Repo.Migrations.AddLinkUndescribedInatArticle do
  @moduledoc """
  Adds the link-undescribed-inat article explaining how to use Gallformers Codes on iNaturalist.
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
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    # Only insert if article doesn't exist
    existing =
      repo().one(from(a in "articles", where: a.slug == "link-undescribed-inat", select: a.id))

    if is_nil(existing) do
      repo().insert_all("articles", [
        %{
          slug: "link-undescribed-inat",
          title: "Using Gallformers Codes on iNaturalist",
          author: "Gallformers Team",
          content: content(),
          tags: "[\"guide\",\"inat\",\"undescribed\"]",
          is_published: 1,
          inserted_at: now,
          updated_at: now
        }
      ])
    end
  end

  def down do
    repo().delete_all(from(a in "articles", where: a.slug == "link-undescribed-inat"))
  end

  defp content do
    ~S"""
    # What is a Gallformers Code?

    Many galls are caused by species that haven't been formally described by scientists yet. While we can recognize these galls by their distinctive appearance on specific host plants, we can't assign them to a named species because the inducing organism hasn't been studied and published in the scientific literature.

    To track observations of these undescribed galls, Gallformers assigns each one a unique **Gallformers Code**. This code is typically based on the host plant and a descriptive element of the gall (for example, `q-lobata-integral-leaf-gall` for an integral leaf gall on *Quercus lobata*).

    # The Gallformers Code Observation Field on iNaturalist

    [iNaturalist](https://www.inaturalist.org) allows users to add custom observation fields to their observations. The **Gallformers Code** observation field lets you tag your gall observations with the corresponding code from our database.

    **Why use it?**

    - **Track undescribed galls**: Since these galls can't be identified to a species on iNaturalist, adding the Gallformers Code creates a way to search for and aggregate observations of the same gall type
    - **Build phenology data**: More observations with codes help us understand when and where these galls appear
    - **Aid future research**: When a taxonomist eventually describes the species, having a corpus of linked observations provides valuable data on distribution, phenology, and host associations
    - **Connect the community**: Other gall enthusiasts can find your observations when researching specific undescribed galls

    # How to Add a Gallformers Code to Your Observation

    ## Step 1: Find the Code

    On any undescribed gall page on Gallformers, you'll see an amber-colored box with the Gallformers Code displayed. You can click the code to copy it to your clipboard.

    ## Step 2: Go to Your iNaturalist Observation

    Navigate to the observation you want to tag. You can do this from your observations page or directly after uploading a new observation.

    ## Step 3: Add the Observation Field

    1. Scroll down to the **Observation Fields** section (below the Data Quality Assessment)
    2. Click **Add a Field...**
    3. Search for "Gallformers Code"
    4. Select the field from the dropdown
    5. Paste or type the code in the value field
    6. Click the checkmark or press Enter to save

    That's it! Your observation is now linked to this specific gall type in the Gallformers system.

    # Finding Observations with a Specific Code

    From any undescribed gall page on Gallformers, click the **"View observations collected with this code on iNaturalist"** link to see all observations that have been tagged with that Gallformers Code.

    You can also search directly on iNaturalist by using the observation field filter in the Explore or Identify pages.

    # Tips for Best Results

    - **Copy the code exactly**: The field value must match exactly, including hyphens and lowercase letters
    - **Use it for undescribed galls only**: Described species should be identified to species level on iNaturalist when possible
    - **Include quality photos**: Clear photos of the gall, any cross-sections, and the host plant help others confirm your identification
    - **Add host plant info**: If you're not certain of the host plant species, make a separate observation of the plant for identification

    # Learn More

    - [FAQ About Undescribed Galls](/articles/undescribedfaq) — comprehensive guide to collecting, rearing, and preserving specimens from undescribed galls
    - [Gall Identification Guide](/articles/idguide) — tips for identifying galls using the Gallformers ID tool
    - [iNaturalist Observation Fields](https://www.inaturalist.org/pages/observation_fields) — iNaturalist documentation on observation fields
    """
  end
end
