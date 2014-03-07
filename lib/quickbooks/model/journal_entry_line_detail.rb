module Quickbooks
  module Model
    class JournalEntryLineDetail < BaseModel
      xml_accessor :posting_type, :from => 'PostingType'
      xml_accessor :entity, :from => 'Entity', :as => Entity
      xml_accessor :account_ref, :from => 'AccountRef', :as => BaseReference
      xml_accessor :class_ref, :from => 'ClassRef', :as => BaseReference

      reference_setters :account_ref, :class_ref

    end
  end
end
