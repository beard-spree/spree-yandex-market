# -*- coding: utf-8 -*-
require 'nokogiri'

module Export
  class GoogleExporter < YandexMarketExporter

    def initialize
    end

    def export
      config = Spree::YandexMarket::Config.instance
      @host = config.preferred_url.sub(%r[^http://],'').sub(%r[/$], '')
      Nokogiri::XML::Builder.new(:encoding => 'utf-8') do |xml|
        xml.rss({ version: '2.0' }.merge(namespaces)) do
          xml.channel do
            xml.title config.preferred_short_name
            xml.link path_to_url('')
            xml.description config.preferred_full_name
            products.each do |product|
              offer_vendor_model(xml, product)
            end
          end
        end
      end.to_xml
    end
    
    protected

    def offer_vendor_model(xml, product)
      product_image = product.images.first
      if product_image.present?
        variants = product.variants.select { |v| v.count_on_hand > 0 }
        variants_count = variants.count
        variants.each do |variant|
          xml.item do
            xml.title model_name(product)
            xml.link "http://#{@host}/id/#{product.id}#{utms}"
            xml.description product_description(product)
            xml['g'].id (variants_count > 1 ? variant.id : product.id)
            xml['g'].condition 'new'
            xml['g'].price variant.price
            xml['g'].availability 'in stock'
            xml['g'].image_link image_url(product_image)
            xml['g'].brand product.brand.name if product.brand
            xml['g'].mpn product.sku
            if product.cat && product.cat.google_merchant_category
              names = product.cat.google_merchant_category.ancestors.reject{ |a| a.level.zero? }.map{ |a| a.name }
              names << product.cat.google_merchant_category.name
              category_name = names.join(' > ')
              xml['g'].google_product_category category_name
              xml['g'].product_type category_name
            end
            ov = variant.option_values.first
            if ov && ov.presentation != 'Без размера'
              xml['g'].size ov.presentation
            end
          end
        end
      end
    end

    def utms
      '?utm_source=google&utm_medium=merchants&utm_campaign=merchants'
    end

    def namespaces
      { 'xmlns:g' => 'http://base.google.com/ns/1.0' }
    end

    def product_description(product)
      if product.description
        strip_tags(product.description)
      else
        model_name(product)
      end
    end

    def model_name(product)
      model = []
      model << product.brand.name if product.brand.present?
      model << product.name
      model << "(#{I18n.t("for_#{GENDER[product.gender].to_s}")})" if product.gender.present?
      model.join(' ')
    end

  end
end