Deface::Override.new(
  virtual_path: "spree/checkout/edit",
  name: "add_paypal_button",
  insert_top: '[data-hook="checkout_form_wrapper"]',
  partial: 'spree/checkout/paypal'
)

Deface::Override.new(
  virtual_path: "spree/orders/edit",
  name: "add_paypal_pay_later_in_cart",
  insert_after: %Q{erb[loud]:contains("render partial: 'summary'")},
  text: <<-EOF
    <div id="cart-paypal-pay-later">
      <div
        data-pp-message
        data-pp-placement="cart"
        data-pp-style-layout="text"
        data-pp-style-text-size="<%= ::Spree::PaymentMethod.find_by(type: "Spree::Gateway::PayPalCheckout")&.preferred_pay_later_text_size %>"
        data-pp-style-logo-type="inline"
        data-pp-style-text-color="black"
        data-pp-amount="<%= @order.total %>"
      >
      </div>
    </div>
    <style>
      #cart-paypal-pay-later {
        margin-top: 0.5em;
      }
    </style>
  EOF
)

Deface::Override.new(
  virtual_path: "spree/orders/edit",
  name: "add_paypal_button_in_cart",
  insert_before: '[data-hook="cart_buttons"]',
  partial: 'spree/checkout/cart_paypal_button'
  
)


