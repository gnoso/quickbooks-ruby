module Quickbooks
  module Model
    class JournalEntry < BaseModel
      XML_COLLECTION_NODE = "JournalEntry"
      XML_NODE = "JournalEntry"
      REST_RESOURCE = 'journalentry'

      xml_accessor :id, :from => 'Id', :as => Integer
      xml_accessor :sync_token, :from => 'SyncToken', :as => Integer
      xml_accessor :meta_data, :from => 'MetaData', :as => MetaData
      xml_accessor :doc_number, :from => 'DocNumber'
      xml_accessor :txn_date, :from => 'TxnDate', :as => Time
      xml_accessor :line_items, :from => 'Line', :as => [Line]
      xml_accessor :private_note, :from => 'PrivateNote'
      xml_accessor :currency_ref, :from => 'CurrencyRef', :as => BaseReference
      xml_accessor :exchange_rate, :from => 'ExchangeRate', :as => Integer

      reference_setters :currency_ref

      validates_length_of :line_items, :minimum => 1

    end
  end
end
