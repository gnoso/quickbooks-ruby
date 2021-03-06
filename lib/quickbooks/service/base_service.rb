module Quickbooks
  module Service
    class BaseService
      include Quickbooks::Util::Logging
      include ServiceCrud

      attr_accessor :company_id
      attr_accessor :oauth
      attr_reader :base_uri
      attr_reader :last_response_body
      attr_reader :last_response_xml

      XML_NS = %{xmlns="http://schema.intuit.com/finance/v3"}
      HTTP_CONTENT_TYPE = 'application/xml'
      HTTP_ACCEPT = 'application/xml'
      HTTP_ACCEPT_ENCODING = 'gzip, deflate'

      def initialize()
        @base_uri = 'https://qb.sbfinance.intuit.com/v3/company'
      end

      def access_token=(token)
        @oauth = token
      end

      def company_id=(company_id)
        @company_id = company_id
      end

      # realm & company are synonymous
      def realm_id=(company_id)
        @company_id = company_id
      end

      def url_for_resource(resource)
        "#{url_for_base}/#{resource}"
      end

      def url_for_base
        "#{@base_uri}/#{@company_id}"
      end

      def url_for_query(query = nil, start_position = 1, max_results = 20)
        query ||= default_model_query
        query = "#{query} STARTPOSITION #{start_position} MAXRESULTS #{max_results}"

        "#{url_for_base}/query?query=#{URI.encode_www_form_component(query)}"
      end

      private

      def parse_xml(xml)
        @last_response_xml = Nokogiri::XML(xml)
      end

      def valid_xml_document(xml)
        %Q{<?xml version="1.0" encoding="utf-8"?>\n#{xml.strip}}
      end

      # A single object response is the same as a collection response except
      # it just has a single main element
      def fetch_object(model, url, params = {}, options = {})
        raise ArgumentError, "missing model to instantiate" if model.nil?
        response = do_http_get(url, params)
        collection = parse_collection(response, model)
        if collection.is_a?(Quickbooks::Collection)
          collection.entries.first
        else
          nil
        end
      end

      def fetch_collection(query, model, options = {})
        page = options.fetch(:page, 1)
        per_page = options.fetch(:per_page, 20)

        start_position = ((page - 1) * per_page) + 1 # page=2, per_page=10 then we want to start at 11
        max_results = per_page
        response = do_http_get(url_for_query(query, start_position, max_results))

        parse_collection(response, model)
      end

      def parse_collection(response, model)
        if response
          collection = Quickbooks::Collection.new
          xml = @last_response_xml
          begin
            results = []

            query_response = xml.xpath("//xmlns:IntuitResponse/xmlns:QueryResponse")[0]
            if query_response

              start_pos_attr = query_response.attributes['startPosition']
              if start_pos_attr
                collection.start_position = start_pos_attr.value.to_i
              end

              max_results_attr = query_response.attributes['maxResults']
              if max_results_attr
                collection.max_results = max_results_attr.value.to_i
              end

              total_count_attr = query_response.attributes['totalCount']
              if total_count_attr
                collection.total_count = total_count_attr.value.to_i
              end
            end

            path_to_nodes = "//xmlns:IntuitResponse//xmlns:#{model::XML_NODE}"
            collection.count = xml.xpath(path_to_nodes).count
            if collection.count > 0
              xml.xpath(path_to_nodes).each do |xa|
                entry = model.from_xml(xa)
                results << entry
              end
            end
            collection.entries = results
          rescue => ex
            raise Quickbooks::IntuitRequestException.new("Error parsing XML: #{ex.message}")
          end
          collection
        else
          nil
        end
      end

      # Given an IntuitResponse which is expected to wrap a single
      # Entity node, e.g.
      # <IntuitResponse xmlns="http://schema.intuit.com/finance/v3" time="2013-11-16T10:26:42.762-08:00">
      #   <Customer domain="QBO" sparse="false">
      #     <Id>1</Id>
      #     ...
      #   </Customer>
      # </IntuitResponse>
      def parse_singular_entity_response(model, xml)
        xmldoc = Nokogiri(xml)
        xmldoc.xpath("//xmlns:IntuitResponse/xmlns:#{model::XML_NODE}")[0]
      end

      # A successful delete request returns a XML packet like:
      # <IntuitResponse xmlns="http://schema.intuit.com/finance/v3" time="2013-04-23T08:30:33.626-07:00">
      #   <Payment domain="QBO" status="Deleted">
      #   <Id>8748</Id>
      #   </Payment>
      # </IntuitResponse>
      def parse_singular_entity_response_for_delete(model, xml)
        xmldoc = Nokogiri(xml)
        xmldoc.xpath("//xmlns:IntuitResponse/xmlns:#{model::XML_NODE}[@status='Deleted']").length == 1
      end

      def perform_write(model, body = "", params = {}, headers = {})
        url = url_for_resource(model::REST_RESOURCE)
        unless headers.has_key?('Content-Type')
          headers['Content-Type'] = 'text/xml'
        end

        response = do_http_post(url, body.strip, params, headers)

        result = nil
        if response
          case response.code.to_i
          when 200
            result = Quickbooks::Model::RestResponse.from_xml(response.plain_body)
          when 401
            raise Quickbooks::IntuitRequestException.new("Authorization failure: token timed out?")
          when 404
            raise Quickbooks::IntuitRequestException.new("Resource Not Found: Check URL and try again")
          end
        end
        result
      end

      def do_http_post(url, body = "", params = {}, headers = {}) # throws IntuitRequestException
        url = add_query_string_to_url(url, params)
        do_http(:post, url, body, headers)
      end

      def do_http_get(url, params = {}, headers = {}) # throws IntuitRequestException
        do_http(:get, url, {}, headers)
      end

      def do_http(method, url, body, headers) # throws IntuitRequestException
        if @oauth.nil?
          raise "OAuth client has not been initialized. Initialize with setter access_token="
        end
        unless headers.has_key?('Content-Type')
          headers['Content-Type'] = HTTP_CONTENT_TYPE
        end
        unless headers.has_key?('Accept')
          headers['Accept'] = HTTP_ACCEPT
        end
        unless headers.has_key?('Accept-Encoding')
          headers['Accept-Encoding'] = HTTP_ACCEPT_ENCODING
        end

        log "------ New Request ------"
        log "METHOD = #{method}"
        log "RESOURCE = #{url}"
        log "BODY(#{body.class}) = #{body == nil ? "<NIL>" : body.inspect}"
        log "HEADERS = #{headers.inspect}"

        response = case method
          when :get
            @oauth.get(url, headers)
          when :post
            @oauth.post(url, body, headers)
          else
            raise "Do not know how to perform that HTTP operation"
          end
        check_response(response)
      end

      def add_query_string_to_url(url, params)
        if params.is_a?(Hash) && !params.empty?
          url + "?" + params.collect { |k| "#{k.first}=#{k.last}" }.join("&")
        else
          url
        end
      end

      def check_response(response)
        log "RESPONSE CODE = #{response.code}"
        log "RESPONSE BODY = #{response.plain_body}"
        parse_xml(response.plain_body)
        status = response.code.to_i
        case status
        when 200
          # even HTTP 200 can contain an error, so we always have to peek for an Error
          if response_is_error?
            parse_and_raise_exception
          else
            response
          end
        when 302
          raise "Unhandled HTTP Redirect"
        when 401
          raise Quickbooks::AuthorizationFailure
        when 400, 500
          parse_and_raise_exception
        when 503
          raise Quickbooks::ServiceUnavailable
        else
          raise "HTTP Error Code: #{status}, Msg: #{response.plain_body}"
        end
      end

      def parse_and_raise_exception
        err = parse_intuit_error
        ex = Quickbooks::IntuitRequestException.new("#{err[:message]}:\n\t#{err[:detail]}")
        ex.code = err[:code]
        ex.detail = err[:detail]
        ex.type = err[:type]

        raise ex
      end

      def response_is_error?
        @last_response_xml.xpath("//xmlns:IntuitResponse/xmlns:Fault")[0] != nil
      end

      def parse_intuit_error
        error = {:message => "", :detail => "", :type => nil, :code => 0}
        fault = @last_response_xml.xpath("//xmlns:IntuitResponse/xmlns:Fault")[0]
        if fault
          error[:type] = fault.attributes['type'].value

          error_element = fault.xpath("//xmlns:Error")[0]
          if error_element
            code_attr = error_element.attributes['code']
            if code_attr
              error[:code] = code_attr.value
            end
            error[:message] = error_element.xpath("//xmlns:Message").text
            error[:detail] = error_element.xpath("//xmlns:Detail").text
          end
        end

        error
      end

    end
  end
end
