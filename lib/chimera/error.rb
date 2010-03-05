module Chimera
  class Error < RuntimeError
    class MissingConfig < Chimera::Error; end
    class UniqueConstraintViolation < Chimera::Error; end
    class SaveWithoutId < Chimera::Error; end
    class MissingId < Chimera::Error; end
    class ValidationErrors < Chimera::Error; end
    class AttemptToModifyId < Chimera::Error; end
    class AssociationClassMismatch < Chimera::Error; end
  end
end

