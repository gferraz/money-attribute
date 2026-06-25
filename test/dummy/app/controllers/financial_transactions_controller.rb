class FinancialTransactionsController < ApplicationController
  before_action :set_financial_transaction, only: %i[show edit update destroy]

  def index
    @financial_transactions = FinancialTransaction.order(created_at: :desc)
  end

  def show
  end

  def new
    @financial_transaction = FinancialTransaction.new
  end

  def edit
  end

  def create
    @financial_transaction = FinancialTransaction.new(financial_transaction_params)

    if @financial_transaction.save
      redirect_to @financial_transaction, notice: "Transaction created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @financial_transaction.update(financial_transaction_params)
      redirect_to @financial_transaction, notice: "Transaction updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @financial_transaction.destroy!
    redirect_to financial_transactions_url, notice: "Transaction deleted."
  end

  private

  def set_financial_transaction
    @financial_transaction = FinancialTransaction.find(params[:id])
  end

  def financial_transaction_params
    params.require(:financial_transaction).permit(:description, :date, :amount, :discount, :price, :tax, :total)
  end
end
