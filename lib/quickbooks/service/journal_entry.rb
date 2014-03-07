module Quickbooks
  module Service
    class JournalEntry < BaseService
      include ServiceCrud

      def default_model_query
        "SELECT * FROM JOURNALENTRY"
      end

      def model
        Quickbooks::Model::JournalEntry
      end
    end
  end
end
