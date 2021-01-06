defmodule Model do
  @moduledoc false

  defmodule Bikes do
    @moduledoc false
    use TypedStruct

    typedstruct do
      field :goal, integer()
      field :bikes, list(Bike.t())
    end
  end

  defmodule Bike do
    @moduledoc false
    use TypedStruct

    typedstruct do
      field :name, String.t()
      field :current, boolean()
      field :data, list(Measurement.t())
    end
  end

  defmodule Measurement do
    @moduledoc false
    use TypedStruct

    typedstruct do
      field :date, String.t()
      field :km, integer()
    end
  end
end
