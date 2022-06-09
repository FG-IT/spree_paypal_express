module PaypalServices
  class Checkout

    def initialize(order, provider)
      @order = order
      @provider = provider
    end

    def valid?(paypal_order_id)
      begin
        request = ::PayPalCheckoutSdk::Orders::OrdersGetRequest::new(paypal_order_id)
        result = ::PaypalServices::Request.request_paypal(@provider, request)
        return true
      rescue PayPalHttp::HttpError => ioe
        return false
      end
    end

    def update_paypal_order
      request = ::PayPalCheckoutSdk::Orders::OrdersPatchRequest::new(@order.paypal_checkout.token)
      result = ::PaypalServices::Request.request_paypal(@provider, request, paypal_order_info)
    end

    def paypal_order_payer_info
      {
        "payer": { 
          "name": {
            "given_name": "John",
            "surname": "Doe"
          },
          "email_address": "befruitful12@gmail.com",
          "phone": {
            "phone_number": {
              "national_number": "9874563210"
            }
          },
          "address": {
            "address_line_1": "10, east street",
            "address_line_2": "second building",
            "admin_area_2": "Mumbai",
            "admin_area_1": "Maharashtra",
            "postal_code": "400029",
            "country_code": "IN"
          }
        }
      }
    end

    def paypal_order_request_info
      purchase_unit = {
        amount: {
          currency_code: @order.currency,
          value: @order.total
        }
      }
      if @order.ship_address.present?
        shipping = {
          name: {
            full_name: @order.ship_address.firstname + " " + @order.ship_address.lastname
          },
          address: {
            address_line_1: @order.ship_address.address1,
            address_line_2: @order.ship_address.address2,
            admin_area_2: @order.ship_address.city,
            admin_area_1: @order.ship_address.state.name,
            postal_code: @order.ship_address.zipcode,
            country_code: @order.ship_address.country.iso
          }
        }
        purchase_unit = purchase_unit.merge(shipping: shipping)
      end
      request_info = { purchase_units: [purchase_unit] }
      if @order.email.present?
        payer = { 
          email_address: @order.email
        }
        request_info = request_info.merge( payer: payer)
      end
      request_info
    end

    def paypal_order_info
      [{
        "op": "replace",
        "path": "/purchase_units/@reference_id=='default'/amount",
        "value": paypal_order_request_info[:purchase_units].first[:amount]
      }]
    end

    def add_shipping_address_from_paypal(result, permitted_attributes)
      if @order.ship_address.blank?
        address = result[:purchase_units].first[:shipping][:address]
        name = result[:purchase_units].first[:shipping][:name]
        country_id = ::Spree::Country.find_by(iso: address[:country_code]).id
        state_id = ::Spree::State.where({abbr: address[:admin_area_1], country_id: country_id}).first.id

        address_params = {
          firstname: result[:payer][:name][:given_name], 
          lastname: result[:payer][:name][:surname], 
          address1: address[:address_line_1],
          address2: address[:address_line_2],
          city: address[:admin_area_2], 
          state_id: state_id.to_s, 
          zipcode: address[:postal_code], 
          country_id: country_id.to_s, 
          phone: address[:phone]
        }

        customer_info_params = { 
          email: result[:payer][:email_address], 
          bill_address_attributes: address_params,
          ship_address_attributes: address_params
        }

        _params = ActionController::Parameters.new({
          order: {
            email: result[:payer][:email_address], 
            bill_address_attributes: address_params,
            use_billing: "1"
          },
          save_user_address: true
        })
        @order.update_from_params(_params, permitted_attributes)
      end
      @order.update_column(:state, "address")
      if @order.paypal_checkout.present?
        @order.paypal_checkout.update!(token: result[:id], state: result[:status], payer_id: result[:payer][:payer_id])
      else
        @order.create_paypal_checkout(token: result[:id], state: result[:status], payer_id: result[:payer][:payer_id])
      end
      @order.next
    end

    def paypal_order_params(intent, return_url, cancel_url, brand_name, user_action)
      {
        intent: intent,
        application_context: {
          return_url: return_url,
          cancel_url: cancel_url,
          brand_name: brand_name,
          user_action: user_action,
          shipping_preference: @order.ship_address.present? ? :SET_PROVIDED_ADDRESS : nil
        }
      }.merge(paypal_order_request_info)
    end

    def complete_with_paypal_checkout(token, payer_id, payment_method)
      @order.payments.create!({
        source: Spree::PaypalCheckout.create({
                                              token: token,
                                              payer_id: payer_id
                                            }),
        amount: @order.total,
        payment_method: payment_method
      })
      @order.next
    end

    def complete_with_paypal_express_payment(payment_method)
      @order.payments.create!({
        source: @order.paypal_checkout,
        amount: @order.total,
        payment_method: payment_method
      })
      @order.next
    end
  end
end