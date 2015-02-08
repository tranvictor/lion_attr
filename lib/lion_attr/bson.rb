module BSON
  class ObjectId
    def to_json(*_args)
      to_s.to_json
    end

    def as_json(*_args)
      to_s.as_json
    end
  end
end
