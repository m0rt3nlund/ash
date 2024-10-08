defmodule Ash.Test.Policy.SelectingTest do
  use ExUnit.Case

  alias Ash.Test.Domain, as: Domain

  defmodule Parent do
    use Ash.Resource,
      domain: Domain,
      data_layer: Ash.DataLayer.Ets,
      authorizers: [Ash.Policy.Authorizer]

    actions do
      default_accept :*
      defaults [:read, :destroy, create: :*, update: :*]
    end

    ets do
      private? true
    end

    attributes do
      uuid_primary_key :id

      attribute :owner_id, :string do
        public?(true)
      end

      attribute :guest_id, :string do
        public?(true)
      end
    end

    relationships do
      has_one :owner_only_resource, Ash.Test.Policy.SelectingTest.OwnerOnlyResource do
        public?(true)
        source_attribute :id
        destination_attribute :parent_id
      end
    end

    policies do
      policy always() do
        authorize_if expr(owner_id == ^actor(:id) or guest_id == ^actor(:id))
      end
    end
  end

  defmodule OwnerOnlyResource do
    use Ash.Resource,
      domain: Domain,
      data_layer: Ash.DataLayer.Ets,
      authorizers: [Ash.Policy.Authorizer]

    actions do
      default_accept :*
      defaults [:read, :destroy, create: :*, update: :*]
    end

    ets do
      private? true
    end

    attributes do
      uuid_primary_key :id

      attribute :parent_id, :uuid do
        public?(true)
      end

      attribute :state, :string do
        public?(true)
      end

      attribute :forbidden_field, :string do
        public?(true)
        default "forbidden"
      end
    end

    relationships do
      belongs_to :owner_resource, Ash.Test.Policy.SelectingTest.Parent do
        public?(true)
        source_attribute :parent_id
        destination_attribute :id
      end
    end

    policies do
      bypass actor_attribute_equals(:id, "owner") do
        authorize_if always()
      end

      policy always() do
        forbid_if selecting(:forbidden_field)

        authorize_if expr(
                       owner_resource.owner_id == ^actor(:id) and state in ["active", "inactive"]
                     )
      end
    end

    field_policies do
      field_policy [:forbidden_field] do
        authorize_if actor_attribute_equals(:id, "owner")
      end

      field_policy :* do
        authorize_if always()
      end
    end
  end

  test "owner can can select forbidden field on related resource" do
    parent =
      Parent
      |> Ash.Changeset.for_create(:create, %{owner_id: "owner", guest_id: "guest"})
      |> Ash.Changeset.for_create(:create)
      |> Ash.create!(authorize?: false)

    OwnerOnlyResource
    |> Ash.Changeset.for_create(:create, %{parent_id: parent.id, state: "active"})
    |> Ash.Changeset.for_create(:create)
    |> Ash.create!(authorize?: false)

    assert {:ok, parent} =
             Parent
             |> Ash.Query.for_read(:read)
             |> Ash.Query.load(:owner_only_resource)
             |> Ash.Query.limit(1)
             |> Ash.read_one(actor: %{id: "owner"})

    refute is_nil(parent.owner_only_resource)
  end

  test "guest is forbidden from querying if selecting a forbidden field on the rel" do
    parent =
      Parent
      |> Ash.Changeset.for_create(:create, %{owner_id: "owner", guest_id: "guest"})
      |> Ash.Changeset.for_create(:create)
      |> Ash.create!(authorize?: false)

    OwnerOnlyResource
    |> Ash.Changeset.for_create(:create, %{parent_id: parent.id, state: "active"})
    |> Ash.Changeset.for_create(:create)
    |> Ash.create!(authorize?: false)

    assert {:ok, %{owner_only_resource: nil}} =
             Parent
             |> Ash.Query.for_read(:read)
             |> Ash.Query.load(:owner_only_resource)
             |> Ash.Query.limit(1)
             |> Ash.read_one(actor: %{id: "guest"})
  end
end
