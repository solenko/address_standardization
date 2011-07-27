# encoding: utf-8

module AddressStandardization
  class MelissaData < AbstractService
    class << self
    protected
      def lookup_us_address(params)
        url = "http://www.melissadata.com/lookups/AddressVerify.asp"
        
        url << "?" + params.join("&")
        url << "&FindAddress=Submit"

        attrs = {:country => "USA"}
        Mechanize.new do |ua|
          AddressStandardization.debug "[MelissaData.lookup_us_address] Hitting URL: #{url}"
          results_page = ua.get(url)
          AddressStandardization.debug "[MelissaData.lookup_us_address] Response body:"
          AddressStandardization.debug "--------------------------------------------------"
          AddressStandardization.debug results_page.body
          AddressStandardization.debug "--------------------------------------------------"

          table = results_page.search("table.Tableresultborder")[0]
          unless table
            AddressStandardization.debug "[MelissaData.lookup_us_address] Unable to find result table"
            return
          end
          
          status_row = table.at("div.Titresultableok")
          unless status_row && status_row.inner_text =~ /Address Verified/
            AddressStandardization.debug "[MelissaData.lookup_us_address] Address not verified"
            return
          end
          main_td = table.search("tr:eq(3)/td:eq(2)")
          main_td_s = main_td.inner_html
          main_td_s.encode!("utf-8") if main_td_s.respond_to?(:encode!)
          street_part, city_state_zip_part = main_td_s.split("<br>")[0..1]
          street = street_part.strip_html.strip_whitespace
          if main_td_s.respond_to?(:encode!)
            # ruby 1.9
            separator = city_state_zip_part.include?("&#160;&#160;") ? "&#160;&#160;" : "  "
          else
            # ruby 1.8
            separator = "\302\240"
          end
          city, state, zip = city_state_zip_part.strip_html.split(separator).delete_if { |el| el.strip.empty? }
          attrs[:street] = street.upcase
          attrs[:city] = city.upcase
          attrs[:province] = attrs[:state] = state.upcase
          attrs[:postalcode] = attrs[:zip] = zip.upcase
        end
        attrs
      end

      def lookup_international_address(params)
        raise "Not implemented"
        attrs = {}
        action = 'addressverify_univ.aspx'
        url = "http://www.melissadata.com/service/lookups/#{action}"
        control_prefix = 'ctl00$ContentPlaceHolder1$UniSearchAddress1$'
        field_prefix = "#{control_prefix}txt"
        Mechanize.new do |ua|
          AddressStandardization.debug "[MelissaData.lookup_international_address] Get form for #{url}"
          form_page = ua.get(url)
          form = form_page.forms.detect { |f| f.action == action }
          unless form
            AddressStandardization.debug "[MelissaData.lookup_international_address] Unable to locate form"
            return attrs
          end

          params.each do |key, value|
            field_name = field_prefix + key
            if form.field(field_name).class.name =~ /Mechanize::Form::SelectList$/
              select_value(form.field(field_name), value)
            else
              form[field_name] = value
            end
          end
          result_page = form.submit(control_prefix + 'Verify Address')
          AddressStandardization.debug "[MelissaData.lookup_international_address] #{result_page.body}"
        end
        attrs
      end

      def select_value(select, value)
        texts = select.options.map { |element| element.text }
        values = select.options.map { |element| element.value }

        return values[texts.index(value)] if texts.include?(value)
        return values[1]
      end

      def get_live_response(address_info)
        address_info = address_info.stringify_keys
        
        is_us = (!address_info.has_key?("country") || address_info["country"].to_s.upcase == "USA")
        params = []
        attrs_to_fields(is_us).each do |attr, field|
          key, val = field, address_info[attr]
          params << "#{key}=#{val.url_escape}" if val
        end
        attrs = {}
        if is_us
          attrs = lookup_us_address(params)
        else
          attrs = lookup_international_address(params)
        end
        if attrs.nil?
          AddressStandardization.debug "[MelissaData.lookup_international_address] Address not verified"
          return
        end
        Address.new(attrs)
      end
      
      def attrs_to_fields(is_us)
        if is_us
          {"street" => 'Address', "city" => 'city', "state" => 'state', "zip" => 'zip'}
        else
          {"street" => 'Street', "city" => 'city', "province" => 'Province', "postalcode" => 'Postcode'}
        end
      end
    end
  end
end