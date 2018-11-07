defmodule Cldr.Backend.Compiler do
  @moduledoc false

  @doc false
  defmacro __before_compile__(env) do
    config =
      Module.get_attribute(env.module, :cldr_opts)
      |> Keyword.put(:backend, env.module)
      |> Cldr.Config.config_from_opts

    Cldr.install_locales(config)
    Module.put_attribute(env.module, :config, config)

    quote location: :keep do
      @moduledoc """
      Provides the core functions to retrieve and manage
      the CLDR data that supports formatting and localisation.

      It provides the core functions to access formatted
      CLDR data, set and retrieve a current locale and validate
      certain core data types such as locales, currencies and
      territories.

      """
      alias Cldr.Config
      alias Cldr.LanguageTag
      alias Cldr.Locale

      def __cldr__(:backend), do: unquote(Map.get(config, :backend))
      def __cldr__(:gettext), do: unquote(Map.get(config, :gettext))
      def __cldr__(:data_dir), do: unquote(Map.get(config, :data_dir))
      def __cldr__(:otp_app), do: unquote(Map.get(config, :otp_app))
      def __cldr__(:config), do: unquote(Macro.escape(config))

      unquote(Cldr.Backend.define_backend_functions(config))
      unquote(Cldr.Locale.define_locale_new(config))
      unquote(Cldr.Number.PluralRule.define_ordinal_and_cardinal_modules(config))
      unquote(Cldr.Config.define_plugin_modules(config))

      if Code.ensure_loaded?(Gettext) do
        unquote(Cldr.Gettext.Plural.define_gettext_plurals_module(config))
      end
    end
  end
end