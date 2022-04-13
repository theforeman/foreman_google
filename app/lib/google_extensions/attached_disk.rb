module GoogleExtensions
  module AttachedDisk
    def persisted?
      type == 'PERSISTENT'
    end

    def id
    end

    def _delete
    end
  end
end
