module WTK

  module Entities
    
    class Order < Grape::Entity
      format_with(:iso_timestamp) { |dt| dt.iso8601 }
        expose :oid, as: :id
        expose :total
        expose :created_by
        expose :created_by_user, using: WTK::Entities::User 
        expose :line_items do |model, opts|
          WTK::Entities::LineItem.represent(model.line_items)
        end
        with_options(format_with: :iso_timestamp) do
          expose :created_at
          expose :updated_at
        end
    end

    class LineItem < Grape::Entity
        #expose :number, documentation: { type: "Integer", desc: "行号" }
        expose :product_id       
        expose :product, using: WTK::Entities::Product
        expose :quantity
        expose :amount
    end

  end

  class Orders < Grape::API

    helpers do
      # params :items do
      #   requires :number, type: String
      #   requires :product_id, type: String
      #   requires :quantity, type: String
      # end
    end

    resource :orders do
      # curl -X POST --data 'id=300&total=30000&created_by=100&line_items[][product_id]=100&line_items[][quantity]=1&line_items[][amount]=100&line_items[][product_id]=200&line_items[][quantity]=2&line_items[][amount]=400&created_at=2015-01-19T07:43:43Z' localhost:3000/api/orders
      desc "创建一个订单"
      params do
        requires :id, type: String, desc: "订单ID"
        requires :total, type: String, desc: "订单总金额"
        requires :created_by, type: String, desc: "订购人ID（已传入微推客系统的用户ID）"
        requires :line_items, type: Array, desc: "订单明细" do
          requires :product_id, type: String, desc: "商品ID（已传入微推客系统的商品ID）"
          requires :quantity, type: String, desc: "购买数量"
          requires :amount, type: String, desc: "金额"
        end
        # requires :line_items, type: Hash, desc: "订单明细" do
        #   requires :number, type: String
        #   requires :product_id, type: String
        #   requires :quantity, type: String
        # end
        optional :created_at, type: String, desc: "订单创建时间，ISO8601格式，如：2015-06-18T18:18:18Z", documentation: { example: '2015-06-18T18:18:18Z' }
      end
      post do
        user = User.find_by(oid: params[:created_by])
        #if @user && 

        order = Order.create!(
                          organization_id: 2,
                          oid:          params[:id],
                          total:        params[:total],
                          created_by:   user.id,
                          created_at:   params[:created_at]
                        )
        lines = params[:line_items]
        lines.length.times do |i|
        begin
          product = Product.find_by(oid: lines[i].product_id)
          rescue ActiveRecord::RecordNotFound 
            error!('未找到指定的商品', 404)
          end
          amount = lines[i].amount
          # amount = lines[i].quantity * product.price unless amount
          order.line_items.create!(
                                    product_id: product.id,
                                    quantity:   lines[i].quantity,
                                    amount:     amount  
                                  )
        end
        present order, :with => Entities::Order
      end

      
      desc "列出全部订单"
      get do
        present Order.where(organization_id: 2), with: Entities::Order, type: :type
        #present statuses, with: API::Entities::Status, type: type
      end


      desc '查询指定的订单'
      params do
        requires :id, type: String, desc: '订单ID'
      end
      route_param :id do
        get do
        begin
          order = Order.find_by(oid: params[:id])
          rescue ActiveRecord::RecordNotFound 
            error!('未找到指定的订单', 404)
          end
          #@org || error!('未找到对应的推客群', 404)
          present order, :with => Entities::Order
        end
      end


      # desc '修改指定订单的信息'
      # params do
      #   requires :id, type: String, desc: "订单ID"
      #   optional :name, type: String, desc: "订单名称"
      #   optional :description, type: String, desc: "订单描述"
      #   optional :image, type: String, desc: "订单图片地址"
      #   optional :price, type: String, desc: "订单实际价格"
      #   optional :retail, type: String, desc: "订单零售价格"
      #   optional :wholesale, type: String, desc: "订单加盟价格"
      # end
      # put ':id' do
      # begin
      #   order = Order.find_by(oid: params[:id])
      #   present order, :with => Entities::Order
      #   rescue ActiveRecord::RecordNotFound 
      #     error!('未找到指定的订单', 404)
      #   end
      #   order.name = params[:name] if params[:name]
      #   order.description = params[:description] if params[:description]
      #   order.image_url = params[:image] if params[:image]
      #   order.price = params[:price] if params[:price]
      #   order.retail = params[:retail] if params[:retail]
      #   order.wholesale = params[:wholesale] if params[:wholesale]
      #   order.save!
      # end

      desc "删除指定订单"
      params do
        requires :id, type: String, desc: "订单ID"
      end
      delete ':id' do
      begin
        order = Order.find_by(oid: params[:id])
        present order, :with => Entities::Order
        rescue ActiveRecord::RecordNotFound 
          error!('未找到指定的订单', 404)
        end 
        #authenticate!
        order.destroy!
      end

    end
  end
end

