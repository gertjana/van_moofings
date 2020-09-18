defmodule Model do

  defmodule Bikes do
    use TypedStruct

    typedstruct do
      field :goal, integer()
      field :bikes, list(Bike.t())
    end
  end

  defmodule Bike do
    use TypedStruct

    typedstruct do
      field :name, String.t()
      field :current, boolean()
      field :data, list(Measurement.t())
    end
  end

  defmodule Measurement do
    use TypedStruct

    typedstruct do
      field :date, String.t()
      field :km, integer()
    end
  end
end
