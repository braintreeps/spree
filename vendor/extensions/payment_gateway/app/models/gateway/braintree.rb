class Gateway::Braintree < Gateway
	preference :merchant_id, :string
	preference :public_key, :string
	preference :private_key, :string

  def provider_class
    ActiveMerchant::Billing::BraintreeGateway
  end

  def authorize(money, creditcard, options = {})
    adjust_options_for_braintree(creditcard, options)
    payment_method = creditcard.gateway_customer_profile_id || creditcard
    provider.authorize(money, payment_method, options)
  end

  def capture(authorization, creditcard, ignored_options)
    amount = (authorization.amount * 100).to_i
    provider.capture(amount, authorization.response_code)
  end

  def create_profile(creditcard, options)
    adjust_country_name(options)
    if creditcard.gateway_customer_profile_id.nil?
      response = provider.store(creditcard, options)
      if response.success?
        creditcard.update_attributes!(:gateway_customer_profile_id => response.params["customer_vault_id"])
      else
        creditcard.gateway_error response.message
      end
    end
  end

  def credit(*args)
    raise NotImplementedError
  end

  def payment_profiles_supported?
    true
  end

  def purchase(money, creditcard, options = {})
    authorize(money, creditcard, options.merge(:submit_for_settlement => true))
  end

  def void(response_code, ignored_creditcard, ignored_options)
    provider.void(response_code)
  end

  protected

  def adjust_country_name(options)
    [:billing_address, :shipping_address].each do |address|
      if options[address] && options[address][:country] == "US"
        options[address][:country] = "United States of America"
      end
    end
  end

  def adjust_billing_address(creditcard, options)
    if creditcard.gateway_customer_profile_id
      options.delete(:billing_address)
    end
  end

  def adjust_options_for_braintree(creditcard, options)
    adjust_country_name(options)
    adjust_billing_address(creditcard, options)
  end
end
