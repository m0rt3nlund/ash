defmodule Mix.Tasks.Ash.Gen.Enum do
  @moduledoc """
  Generates an Ash.Type.Enum

  For example `mix ash.gen.enum The.Enum.Name list,of,values`

  ## Options

  - `--short-name`, `-s`: Register the type under the provided shortname, so it can be referenced like `:short_name` instead of the module name.
  """

  @shortdoc "Generates an Ash.Type.Enum"
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter, [module_name, types | argv]) do
    enum = Igniter.Code.Module.parse(module_name)
    file_name = Igniter.Code.Module.proper_location(enum)

    {opts, _argv} =
      OptionParser.parse!(argv, switches: [short_name: :string], aliases: [s: :short_name])

    short_name =
      if opts[:short_name] do
        String.to_atom(opts[:short_name])
      end

    types =
      types
      |> String.split(",")
      |> Enum.map(&String.to_atom/1)

    igniter
    |> Igniter.create_new_elixir_file(file_name, """
    defmodule #{inspect(enum)} do
      use Ash.Type.Enum, values: #{inspect(types)}
    end
    """)
    |> then(fn igniter ->
      if short_name do
        Igniter.Project.Config.configure(
          igniter,
          "config.exs",
          :ash,
          [:custom_types, short_name],
          enum
        )
      else
        igniter
      end
    end)
  end
end
