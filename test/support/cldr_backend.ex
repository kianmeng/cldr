# Test with Gettext
defmodule WithGettextBackend.Cldr do
  use Cldr,
    gettext: TestGettext.Gettext,
    providers: []
end

defmodule TestBackend.Cldr do
  use Cldr,
    default_locale: "en-001",
    locales: :all,
    gettext: TestGettext.Gettext,
    precompile_transliterations: [{:latn, :arab}, {:arab, :thai}, {:arab, :latn}],
    providers: []
end

# Tests when there is no config
defmodule DefaultBackend.Cldr do
  use Cldr,
    generate_docs: false,
    providers: []
end

# Tests when there are locales but no default
defmodule AnotherBackend.Cldr do
  use Cldr,
    locales: ["en"],
    data_dir: "./another_backend/cldr/data_dir",
    providers: []
end

# Test with not Gettext
defmodule WithNoGettextBackend.Cldr do
  use Cldr,
    providers: []
end

# Tests with otp_app
defmodule WithOtpAppBackend.Cldr do
  use Cldr,
    locales: ["fr", "en"],
    otp_app: :logger,
    providers: []
end


defmodule WithGettextPlural.Cldr do
  use Cldr,
    locales: ["en", "it", "pl"],
    gettext: TestGettext.GettextWithCldrPlural,
    providers: []
end
