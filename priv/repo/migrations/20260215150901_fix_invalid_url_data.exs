defmodule Gallformers.Repo.Migrations.FixInvalidUrlData do
  use Gallformers.Migration

  def up do
    # source.link — fix 8 bad records

    # Missing scheme: prepend https://
    for id <- [393, 504, 787, 805, 835] do
      execute("UPDATE source SET link = 'https://' || link WHERE id = #{id}")
    end

    # Not a URL (title/citation text pasted into link field): clear to empty string
    for id <- [491, 588] do
      execute("UPDATE source SET link = '' WHERE id = #{id}")
    end

    # Literal 'none': clear to empty string
    execute("UPDATE source SET link = '' WHERE id = 622")

    # species_source.externallink — fix 4 bad records

    # Leading space: trim
    execute("UPDATE species_source SET externallink = trim(externallink) WHERE id = 522")

    # Corrupt prefix 'blanda': remove it
    execute(
      "UPDATE species_source SET externallink = replace(externallink, 'blanda', '') WHERE id = 1524"
    )

    # Whitespace only: clear to empty string
    execute("UPDATE species_source SET externallink = '' WHERE id = 5943")

    # Missing scheme: prepend https://
    execute(
      "UPDATE species_source SET externallink = 'https://' || externallink WHERE id = 7943"
    )
  end

  def down do
    # These are data corrections; reverting would reintroduce bad data.
    # No-op is intentional.
    :ok
  end
end
