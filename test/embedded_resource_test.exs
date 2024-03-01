defmodule Ash.Test.Changeset.EmbeddedResourceTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Ash.Changeset

  require Ash.Query

  defmodule Increasing do
    use Ash.Resource.Validation

    def init(opts), do: {:ok, opts}

    def validate(changeset, opts, _) do
      field = Keyword.get(opts, :field)

      if Changeset.changing_attribute?(changeset, field) do
        if Map.get(changeset.data, field) >=
             Changeset.get_attribute(changeset, field) do
          {:error, message: "must be increasing", field: field}
        else
          :ok
        end
      else
        :ok
      end
    end
  end

  defmodule DestroyMe do
    use Ash.Resource.Validation

    def init(opts), do: {:ok, opts}

    def validate(changeset, _opts, _) do
      if Changeset.get_attribute(changeset, :first_name) == "destroy" &&
           Changeset.get_attribute(changeset, :last_name) == "me" do
        :ok
      else
        {:error, "must be named \"destroy me\" to remove a profile"}
      end
    end
  end

  defmodule ProfileWithId do
    use Ash.Resource, data_layer: :embedded

    attributes do
      uuid_primary_key :id, writable?: true

      attribute :first_name, :string do
        public?(true)
      end

      attribute :last_name, :string do
        public?(true)
      end

      attribute :counter, :integer, default: 0, allow_nil?: false, public?: true
    end

    validations do
      validate present([:first_name, :last_name])
      validate {Increasing, field: :counter}, on: :update
      validate {DestroyMe, []}, on: :destroy
    end

    calculations do
      calculate :full_name, :string, concat([:first_name, :last_name], " ") do
        public? true
      end
    end
  end

  defmodule Profile do
    use Ash.Resource, data_layer: :embedded

    attributes do
      attribute :first_name, :string do
        public?(true)
      end

      attribute :last_name, :string do
        public?(true)
      end

      attribute :counter, :integer, default: 0, allow_nil?: false, public?: true
    end

    validations do
      validate present([:first_name, :last_name])
      validate {Increasing, field: :counter}, on: :update
      validate {DestroyMe, []}, on: :destroy
    end

    calculations do
      calculate :full_name, :string, concat([:first_name, :last_name], " ") do
        public? true
      end
    end
  end

  defmodule Tag do
    use Ash.Resource, data_layer: :embedded

    attributes do
      attribute :name, :string do
        public?(true)
      end

      attribute :score, :integer do
        public?(true)
      end
    end

    validations do
      # You can't remove a tag unless you first set its score to 0
      validate absent(:score), on: :destroy
      validate {Increasing, field: :score}, on: :update
      validate present(:score), on: :create
    end
  end

  defmodule TagWithNoNils do
    use Ash.Resource, data_layer: :embedded, embed_nil_values?: false

    attributes do
      attribute :name, :string do
        public?(true)
      end

      attribute :score, :integer do
        public?(true)
      end
    end

    validations do
      # You can't remove a tag unless you first set its score to 0
      validate absent(:score), on: :destroy
      validate {Increasing, field: :score}, on: :update
      validate present(:score), on: :create
    end
  end

  defmodule TagWithId do
    use Ash.Resource, data_layer: :embedded

    attributes do
      uuid_primary_key :id, writable?: true

      attribute :type, :string do
        public?(true)
      end

      attribute :name, :string do
        public?(true)
      end

      attribute :score, :integer do
        public?(true)
      end
    end

    validations do
      # You can't remove a tag unless you first set its score to 0
      validate absent(:score), on: :destroy
      validate {Increasing, field: :score}, on: :update
      validate present(:score), on: :create
    end
  end

  defmodule UnionTagWithId do
    use Ash.Type.NewType,
      subtype_of: :union,
      constraints: [
        types: [
          tag: [
            type: TagWithId,
            tag: :type,
            tag_value: :tag_with_id
          ]
        ]
      ]
  end

  defmodule Author do
    use Ash.Resource,
      domain: Ash.Test.Changeset.EmbeddedResourceTest.Domain,
      data_layer: Ash.DataLayer.Ets

    ets do
      private?(true)
    end

    actions do
      create :create
      update :update
    end

    attributes do
      uuid_primary_key :id, writable?: true

      attribute :profile, Profile,
        constraints: [
          load: [:full_name]
        ],
        public?: true

      attribute :profile_with_id, ProfileWithId,
        constraints: [
          load: [:full_name]
        ],
        public?: true

      attribute :tags, {:array, Tag} do
        public?(true)
      end

      attribute :tags_max_length, {:array, Tag} do
        public?(true)
        constraints max_length: 2, min_length: 1
      end

      attribute :tags_with_id, {:array, TagWithId} do
        public?(true)
      end

      attribute :union_tags_with_id, {:array, UnionTagWithId} do
        public?(true)
      end
    end
  end

  defmodule Domain do
    @moduledoc false
    use Ash.Domain

    resources do
      resource Author
    end
  end

  test "embedded resources can be created" do
    assert %{profile: %Profile{}, tags: [%Tag{name: "trainer"}, %Tag{name: "human"}]} =
             Changeset.for_create(
               Author,
               :create,
               %{
                 profile: %{
                   first_name: "ash",
                   last_name: "ketchum"
                 },
                 tags: [
                   %{name: "trainer", score: 10},
                   %{name: "human", score: 100}
                 ]
               }
             )
             |> Domain.create!()
  end

  test "embed_nil_values?: false causes nil values not to be dumped" do
    value = %TagWithNoNils{name: "foo", score: nil}
    assert {:ok, dumped} = Ash.Type.dump_to_embedded(TagWithNoNils, value, [])
    assert Map.keys(dumped) == [:name]
  end

  test "embedded resources can be constrained with min/max length" do
    assert_raise Ash.Error.Invalid, ~r/must have 2 or fewer items/, fn ->
      Changeset.for_create(
        Author,
        :create,
        %{
          profile: %{
            first_name: "ash",
            last_name: "ketchum"
          },
          tags_max_length: [
            %{name: "trainer", score: 10},
            %{name: "human", score: 100},
            %{name: "gym_leader", score: 150}
          ]
        }
      )
      |> Domain.create!()
    end

    assert_raise Ash.Error.Invalid, ~r/must have 1 or more items/, fn ->
      Changeset.for_create(
        Author,
        :create,
        %{
          profile: %{
            first_name: "ash",
            last_name: "ketchum"
          },
          tags_max_length: []
        }
      )
      |> Domain.create!()
    end
  end

  test "embedded resources support calculations" do
    assert %{profile: %Profile{full_name: "ash ketchum"}} =
             Changeset.for_create(
               Author,
               :create,
               %{
                 profile: %{
                   first_name: "ash",
                   last_name: "ketchum"
                 }
               }
             )
             |> Domain.create!()
  end

  test "embedded resources run validations on create" do
    msg =
      ~r/Invalid value provided for last_name: exactly 2 of first_name,last_name must be present/

    assert_raise Ash.Error.Invalid,
                 msg,
                 fn ->
                   Author
                   |> Changeset.for_create(
                     :create,
                     %{
                       profile: %{
                         first_name: "ash"
                       }
                     }
                   )
                   |> Domain.create!()
                 end
  end

  test "embedded resources run validations on update" do
    assert author =
             Changeset.for_create(
               Author,
               :create,
               %{
                 profile: %{
                   first_name: "ash",
                   last_name: "ketchum"
                 }
               }
             )
             |> Domain.create!()

    input = %{counter: author.profile.counter - 1}

    assert_raise Ash.Error.Invalid,
                 ~r/Invalid value provided for counter: must be increasing/,
                 fn ->
                   Changeset.for_update(
                     author,
                     :update,
                     %{
                       profile: input
                     }
                   )
                   |> Domain.update!()
                 end
  end

  test "embedded resources run validations on destroy" do
    assert author =
             Changeset.for_create(
               Author,
               :create,
               %{
                 profile: %{
                   first_name: "ash",
                   last_name: "ketchum"
                 }
               }
             )
             |> Domain.create!()

    assert_raise Ash.Error.Invalid, ~r/must be named "destroy me" to remove a profile/, fn ->
      Changeset.for_update(
        author,
        :update,
        %{profile: nil}
      )
      |> Domain.update!()
    end

    author =
      Changeset.for_update(
        author,
        :update,
        %{profile: %{first_name: "destroy", last_name: "me"}}
      )
      |> Domain.update!()

    Changeset.for_update(
      author,
      :update,
      %{profile: nil}
    )
    |> Domain.update!()
  end

  test "when a non-array embedded resource has a public primary key, changes are considered a destroy + create, not an update" do
    assert author =
             Changeset.for_create(
               Author,
               :create,
               %{
                 profile_with_id: %{
                   first_name: "ash",
                   last_name: "ketchum"
                 }
               }
             )
             |> Domain.create!()

    assert_raise Ash.Error.Invalid, ~r/must be named "destroy me" to remove a profile/, fn ->
      Changeset.for_update(
        author,
        :update,
        %{profile_with_id: %{first_name: "foo", last_name: "bar"}}
      )
      |> Domain.update!()
    end

    author =
      Changeset.for_update(
        author,
        :update,
        %{
          profile_with_id: %{
            id: author.profile_with_id.id,
            first_name: "destroy",
            last_name: "me"
          }
        }
      )
      |> Domain.update!()

    Changeset.for_update(
      author,
      :update,
      %{profile_with_id: %{first_name: "foo", last_name: "bar"}}
    )
    |> Domain.update!()
  end

  test "a list of embeds without an id are destroyed and created each time" do
    assert author =
             Changeset.for_create(
               Author,
               :create,
               %{
                 tags: [
                   %{name: "trainer", score: 10},
                   %{name: "human", score: 100}
                 ]
               }
             )
             |> Domain.create!()

    assert_raise Ash.Error.Invalid,
                 ~r/Invalid value provided for score: must be present/,
                 fn ->
                   Changeset.for_update(
                     author,
                     :update,
                     %{
                       tags: [
                         %{name: "pokemon"}
                       ]
                     }
                   )
                   |> Domain.update!()
                 end

    assert_raise Ash.Error.Invalid,
                 ~r/Invalid value provided for score: must be absent/,
                 fn ->
                   Changeset.for_update(
                     author,
                     :update,
                     %{
                       tags: [
                         %{name: "pokemon", score: 1}
                       ]
                     }
                   )
                   |> Domain.update!()
                 end
  end

  test "a list of embeds are updated where appropriate" do
    assert %{tags_with_id: [tag]} =
             author =
             Changeset.for_create(
               Author,
               :create,
               %{
                 tags_with_id: [
                   %{name: "trainer", score: 10}
                 ]
               }
             )
             |> Domain.create!()

    exception =
      assert_raise Ash.Error.Invalid,
                   ~r/Invalid value provided for score: must be increasing/,
                   fn ->
                     Changeset.for_update(
                       author,
                       :update,
                       %{
                         tags_with_id: [
                           %{id: tag.id, score: 1}
                         ]
                       }
                     )
                     |> Domain.update!()
                   end

    assert Enum.at(exception.errors, 0).path == [:tags_with_id, 0]

    applied_author =
      Changeset.for_update(
        author,
        :update,
        %{
          tags_with_id: [
            %{id: tag.id, score: 100}
          ]
        }
      )
      |> Domain.update!()

    # The ID of the Tag should not change
    assert Enum.map(applied_author.tags_with_id, & &1.id) ==
             Enum.map(author.tags_with_id, & &1.id)
  end

  test "a list of union embeds are updated where appropriate" do
    assert %{union_tags_with_id: [%Ash.Union{value: tag}]} =
             author =
             Changeset.for_create(
               Author,
               :create,
               %{
                 union_tags_with_id: [
                   %{name: "trainer", score: 10, type: "tag_with_id"}
                 ]
               }
             )
             |> Domain.create!()

    applied_author =
      Changeset.for_update(
        author,
        :update,
        %{
          union_tags_with_id: [
            %{id: tag.id, score: 100, type: "tag_with_id"}
          ]
        }
      )
      |> Domain.update!()

    # The id of the Union Tag should not change
    assert Enum.map(applied_author.union_tags_with_id, & &1.value.id) ==
             Enum.map(author.union_tags_with_id, & &1.value.id)
  end
end
