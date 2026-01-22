defmodule Gallformers.Repo.Migrations.AddSortOrderToImages do
  use Ecto.Migration

  def change do
    alter table(:image) do
      add :sort_order, :integer, default: 0, null: false
    end

    # Create index for efficient ordering queries
    create index(:image, [:species_id, :sort_order])

    # Populate sort_order based on current ordering logic:
    # default DESC (true=1 first), source title ASC, id ASC
    execute(
      """
      UPDATE image
      SET sort_order = (
        SELECT row_num FROM (
          SELECT
            i.id,
            ROW_NUMBER() OVER (
              PARTITION BY i.species_id
              ORDER BY i."default" DESC, COALESCE(s.title, ''), i.id ASC
            ) - 1 as row_num
          FROM image i
          LEFT JOIN source s ON i.source_id = s.id
        ) ranked
        WHERE ranked.id = image.id
      )
      """,
      # Down migration: no-op since we're dropping the column anyway
      "SELECT 1"
    )
  end
end
