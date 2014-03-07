module Quickbooks
   module Model
     class Entity < BaseModel
       xml_accessor :type, :from => 'Type'
       xml_accessor :entity_ref, :from => 'EntityRef', :as => BaseReference

       reference_setters :entity_ref
     end
   end
end
