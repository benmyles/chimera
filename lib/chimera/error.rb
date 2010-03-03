module Chimera
  class Error < RuntimeError
    class MissingConfig < Chimera::Error; end
    class UniqueConstraintViolation < Chimera::Error; end
    class SaveWithoutId < Chimera::Error; end
    class ValidationErrors < Chimera::Error; end
  end
end

