class Api::V1::RetailOrdersController < ApplicationController

  def api
    @retail_orders = RetailOrder.where(status: "ACTIVE").where(in_process: [nil, false])
  end

end
