module Quickbooks
  module Model
    class JournalEntryLine < BaseModel
      xml_accessor :id, :from => 'Id', :as => Integer
      xml_accessor :description, :from => 'Description'
      xml_accessor :amount, :from => 'Amount', :as => BigDecimal, :to_xml => Proc.new { |val| val.to_f }
      xml_accessor :detail_type, :from => 'DetailType'

      #== Various detail types
      xml_accessor :sales_item_line_detail, :from => 'JournalEntryLineDetail', :as => JournalEntryLineDetail

    end
  end
end
