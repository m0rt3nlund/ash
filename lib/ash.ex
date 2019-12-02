defmodule Ash do
  alias Ash.Resource.Relationships.{BelongsTo, HasOne, HasMany, ManyToMany}

  @type record :: struct
  @type cardinality_one_relationship() :: HasOne.t() | BelongsTo.t()
  @type cardinality_many_relationship() :: HasMany.t() | ManyToMany.t()
  @type relationship :: cardinality_one_relationship() | cardinality_many_relationship()
  @type query :: struct
  @type resource :: module
  @type api :: module
  @type error :: struct
  @type filter :: map()
  @type sort :: Keyword.t()
  @type side_loads :: Keyword.t()

  def resources(api) do
    api.resources()
  end

  def primary_key(resource) do
    resource.primary_key()
  end

  def relationship(resource, relationship_name) when is_bitstring(relationship_name) do
    Enum.find(resource.relationships(), &(to_string(&1.name) == relationship_name))
  end

  def relationship(resource, relationship_name) do
    # TODO: Make this happen at compile time
    Enum.find(resource.relationships(), &(&1.name == relationship_name))
  end

  def relationships(resource) do
    resource.relationships()
  end

  def side_load_config(api) do
    api.side_load_config()
  end

  def primary_action(resource, type) do
    resource
    |> actions()
    |> Enum.filter(&(&1.type == type))
    |> case do
      [action] -> action
      actions -> Enum.find(actions, & &1.primary?)
    end
  end

  def action(resource, name, type) do
    Enum.find(resource.actions(), &(&1.name == name && &1.type == type))
  end

  def actions(resource) do
    resource.actions()
  end

  def attribute(resource, name) when is_bitstring(name) do
    Enum.find(resource.attributes, &(to_string(&1.name) == name))
  end

  def attribute(resource, name) do
    Enum.find(resource.attributes, &(&1.name == name))
  end

  def attributes(resource) do
    resource.attributes()
  end

  def name(resource) do
    resource.name()
  end

  def type(resource) do
    resource.type()
  end

  def max_page_size(api, resource) do
    min(api.max_page_size(), resource.max_page_size())
  end

  def default_page_size(api, resource) do
    min(api.default_page_size(), resource.default_page_size())
  end

  def data_layer(resource) do
    resource.data_layer()
  end

  # # TODO: auth
  # def create(resource, attributes, relationships, params \\ %{}) do
  #   action = Map.get(params, :action) || primary_action(resource, :create)
  #   Ash.DataLayer.Actions.run_create_action(resource, action, attributes, relationships, params)
  # end

  # # TODO: auth
  # def update(%resource{} = record, attributes, relationships, params \\ %{}) do
  #   action = Map.get(params, :action) || primary_action(resource, :update)
  #   Ash.DataLayer.Actions.run_update_action(record, action, attributes, relationships, params)
  # end

  # # TODO: auth
  # def destroy(%resource{} = record, params \\ %{}) do
  #   action = Map.get(params, :action) || primary_action(resource, :destroy)
  #   Ash.DataLayer.Actions.run_destroy_action(record, action, params)
  # end

  ## Datalayer shit TODO move this elsewhere
end
