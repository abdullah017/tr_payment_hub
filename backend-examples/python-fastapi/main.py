"""
TR Payment Hub - Python FastAPI Backend Example

This is a reference implementation for the proxy mode backend.
Use this as a starting point for your own backend implementation.

Endpoints:
- POST /payment/create      - Create a payment
- POST /payment/3ds/init    - Initialize 3DS payment
- POST /payment/3ds/complete - Complete 3DS payment
- GET  /payment/installments - Query installment options
- POST /payment/refund      - Process refund
- GET  /payment/status/{id} - Get payment status
- GET  /payment/cards       - List saved cards
- POST /payment/cards/charge - Charge saved card
- DELETE /payment/cards/{token} - Delete saved card
"""

import os
import time
from typing import Any, Optional
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import iyzipay

load_dotenv()

app = FastAPI(
    title="TR Payment Hub Backend",
    description="Backend proxy for tr_payment_hub Flutter package",
    version="1.0.0",
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# iyzico configuration
options = {
    "api_key": os.getenv("IYZICO_API_KEY"),
    "secret_key": os.getenv("IYZICO_SECRET_KEY"),
    "base_url": os.getenv("IYZICO_BASE_URL", "https://sandbox-api.iyzipay.com"),
}


# Pydantic models
class CardInfo(BaseModel):
    cardHolderName: str
    cardNumber: str
    expireMonth: str
    expireYear: str
    cvc: str
    registerCard: bool = False


class BuyerInfo(BaseModel):
    id: str
    name: str
    surname: str
    email: str
    phone: str
    ip: str
    city: str
    country: str
    address: str
    identityNumber: Optional[str] = "11111111111"


class BasketItem(BaseModel):
    id: str
    name: str
    category: str
    price: float
    itemType: str = "physical"


class PaymentRequest(BaseModel):
    orderId: str
    amount: float
    paidPrice: Optional[float] = None
    currency: str = "tryLira"
    installment: int = 1
    card: CardInfo
    buyer: BuyerInfo
    basketItems: list[BasketItem]
    callbackUrl: Optional[str] = None


class RefundRequest(BaseModel):
    transactionId: str
    amount: float


class ChargeRequest(BaseModel):
    cardToken: str
    cardUserKey: str
    orderId: str
    amount: float
    buyer: BuyerInfo
    basketItems: list[BasketItem]


class ThreeDSCompleteRequest(BaseModel):
    transactionId: str
    callbackData: Optional[dict] = None


# Helper functions
def map_currency(currency: str) -> str:
    """Convert Flutter currency to iyzico currency code."""
    mapping = {
        "tryLira": "TRY",
        "usd": "USD",
        "eur": "EUR",
        "gbp": "GBP",
    }
    return mapping.get(currency, "TRY")


def map_payment_request(req: PaymentRequest) -> dict:
    """Convert Flutter request to iyzico format."""
    paid_price = req.paidPrice or req.amount
    return {
        "locale": "tr",
        "conversationId": req.orderId,
        "price": str(req.amount),
        "paidPrice": str(paid_price),
        "currency": map_currency(req.currency),
        "installment": str(req.installment),
        "basketId": req.orderId,
        "paymentChannel": "WEB",
        "paymentGroup": "PRODUCT",
        "paymentCard": {
            "cardHolderName": req.card.cardHolderName,
            "cardNumber": req.card.cardNumber,
            "expireMonth": req.card.expireMonth,
            "expireYear": req.card.expireYear,
            "cvc": req.card.cvc,
            "registerCard": "1" if req.card.registerCard else "0",
        },
        "buyer": {
            "id": req.buyer.id,
            "name": req.buyer.name,
            "surname": req.buyer.surname,
            "gsmNumber": req.buyer.phone,
            "email": req.buyer.email,
            "identityNumber": req.buyer.identityNumber or "11111111111",
            "registrationAddress": req.buyer.address,
            "ip": req.buyer.ip,
            "city": req.buyer.city,
            "country": req.buyer.country,
        },
        "shippingAddress": {
            "contactName": f"{req.buyer.name} {req.buyer.surname}",
            "city": req.buyer.city,
            "country": req.buyer.country,
            "address": req.buyer.address,
        },
        "billingAddress": {
            "contactName": f"{req.buyer.name} {req.buyer.surname}",
            "city": req.buyer.city,
            "country": req.buyer.country,
            "address": req.buyer.address,
        },
        "basketItems": [
            {
                "id": item.id,
                "name": item.name,
                "category1": item.category,
                "itemType": "PHYSICAL" if item.itemType == "physical" else "VIRTUAL",
                "price": str(item.price),
            }
            for item in req.basketItems
        ],
    }


def map_payment_response(result: dict) -> dict:
    """Map iyzico response to Flutter format."""
    if result.get("status") == "success":
        return {
            "success": True,
            "transactionId": result.get("paymentId"),
            "paymentId": result.get("paymentId"),
            "amount": float(result.get("price", 0)),
            "paidAmount": float(result.get("paidPrice", 0)),
            "installment": result.get("installment"),
            "cardType": result.get("cardType"),
            "cardAssociation": result.get("cardAssociation"),
            "binNumber": result.get("binNumber"),
            "lastFourDigits": result.get("lastFourDigits"),
        }
    return {
        "success": False,
        "errorCode": result.get("errorCode", "unknown"),
        "errorMessage": result.get("errorMessage", "Unknown error"),
    }


# Endpoints
@app.post("/payment/create")
async def create_payment(request: PaymentRequest):
    """Create a payment."""
    try:
        iyzico_request = map_payment_request(request)
        payment = iyzipay.Payment().create(iyzico_request, options)
        result = payment.read()

        if isinstance(result, str):
            import json
            result = json.loads(result)

        response = map_payment_response(result)
        if not response["success"]:
            raise HTTPException(status_code=400, detail=response)
        return response

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail={"success": False, "errorCode": "server_error", "errorMessage": str(e)},
        )


@app.post("/payment/3ds/init")
async def init_3ds_payment(request: PaymentRequest):
    """Initialize 3DS payment."""
    try:
        iyzico_request = map_payment_request(request)
        iyzico_request["callbackUrl"] = request.callbackUrl

        threeds_init = iyzipay.ThreedsInitialize().create(iyzico_request, options)
        result = threeds_init.read()

        if isinstance(result, str):
            import json
            result = json.loads(result)

        if result.get("status") == "success":
            return {
                "success": True,
                "status": "pending",
                "transactionId": result.get("conversationId"),
                "htmlContent": result.get("threeDSHtmlContent"),
            }

        raise HTTPException(
            status_code=400,
            detail={
                "success": False,
                "errorCode": result.get("errorCode", "3ds_init_failed"),
                "errorMessage": result.get("errorMessage", "3DS initialization failed"),
            },
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail={"success": False, "errorCode": "server_error", "errorMessage": str(e)},
        )


@app.post("/payment/3ds/complete")
async def complete_3ds_payment(request: ThreeDSCompleteRequest):
    """Complete 3DS payment."""
    try:
        iyzico_request = {
            "locale": "tr",
            "conversationId": request.transactionId,
            "paymentId": (request.callbackData or {}).get("paymentId", request.transactionId),
        }

        threeds_payment = iyzipay.ThreedsPayment().create(iyzico_request, options)
        result = threeds_payment.read()

        if isinstance(result, str):
            import json
            result = json.loads(result)

        response = map_payment_response(result)
        if not response["success"]:
            raise HTTPException(status_code=400, detail=response)
        return response

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail={"success": False, "errorCode": "server_error", "errorMessage": str(e)},
        )


@app.get("/payment/installments")
async def get_installments(
    binNumber: str = Query(..., min_length=6, max_length=8),
    amount: float = Query(..., gt=0),
):
    """Query installment options."""
    try:
        iyzico_request = {
            "locale": "tr",
            "conversationId": str(int(time.time())),
            "binNumber": binNumber,
            "price": str(amount),
        }

        installment_info = iyzipay.InstallmentInfo().retrieve(iyzico_request, options)
        result = installment_info.read()

        if isinstance(result, str):
            import json
            result = json.loads(result)

        if result.get("status") == "success":
            details = result.get("installmentDetails", [])
            if details:
                detail = details[0]
                return {
                    "success": True,
                    "binNumber": detail.get("binNumber"),
                    "bankName": detail.get("bankName"),
                    "bankCode": detail.get("bankCode"),
                    "cardType": detail.get("cardType"),
                    "cardAssociation": detail.get("cardAssociation"),
                    "options": [
                        {
                            "installmentNumber": opt.get("installmentNumber"),
                            "installmentPrice": float(opt.get("installmentPrice", 0)),
                            "totalPrice": float(opt.get("totalPrice", 0)),
                        }
                        for opt in detail.get("installmentPrices", [])
                    ],
                }

        raise HTTPException(
            status_code=400,
            detail={
                "success": False,
                "errorCode": result.get("errorCode", "no_installments"),
                "errorMessage": result.get("errorMessage", "No installment options found"),
            },
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail={"success": False, "errorCode": "server_error", "errorMessage": str(e)},
        )


@app.post("/payment/refund")
async def refund_payment(request: RefundRequest):
    """Process refund."""
    try:
        iyzico_request = {
            "locale": "tr",
            "conversationId": str(int(time.time())),
            "paymentTransactionId": request.transactionId,
            "price": str(request.amount),
            "currency": "TRY",
        }

        refund = iyzipay.Refund().create(iyzico_request, options)
        result = refund.read()

        if isinstance(result, str):
            import json
            result = json.loads(result)

        if result.get("status") == "success":
            return {
                "success": True,
                "refundId": result.get("paymentTransactionId"),
                "refundedAmount": float(result.get("price", 0)),
            }

        raise HTTPException(
            status_code=400,
            detail={
                "success": False,
                "errorCode": result.get("errorCode", "refund_failed"),
                "errorMessage": result.get("errorMessage", "Refund failed"),
            },
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail={"success": False, "errorCode": "server_error", "errorMessage": str(e)},
        )


@app.get("/payment/status/{payment_id}")
async def get_payment_status(payment_id: str):
    """Get payment status."""
    try:
        iyzico_request = {
            "locale": "tr",
            "conversationId": str(int(time.time())),
            "paymentId": payment_id,
        }

        payment = iyzipay.Payment().retrieve(iyzico_request, options)
        result = payment.read()

        if isinstance(result, str):
            import json
            result = json.loads(result)

        if result.get("status") == "success":
            return {
                "success": True,
                "status": "success" if result.get("paymentStatus") == "1" else "pending",
            }

        raise HTTPException(
            status_code=400,
            detail={
                "success": False,
                "errorCode": result.get("errorCode", "status_check_failed"),
                "errorMessage": result.get("errorMessage", "Status check failed"),
            },
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail={"success": False, "errorCode": "server_error", "errorMessage": str(e)},
        )


@app.get("/payment/cards")
async def list_saved_cards(cardUserKey: str = Query(...)):
    """List saved cards."""
    try:
        iyzico_request = {
            "locale": "tr",
            "conversationId": str(int(time.time())),
            "cardUserKey": cardUserKey,
        }

        card_list = iyzipay.CardList().retrieve(iyzico_request, options)
        result = card_list.read()

        if isinstance(result, str):
            import json
            result = json.loads(result)

        if result.get("status") == "success":
            return {
                "success": True,
                "cards": [
                    {
                        "cardToken": card.get("cardToken"),
                        "cardAlias": card.get("cardAlias"),
                        "binNumber": card.get("binNumber"),
                        "lastFourDigits": card.get("lastFourDigits"),
                        "cardType": card.get("cardType"),
                        "cardAssociation": card.get("cardAssociation"),
                    }
                    for card in result.get("cardDetails", [])
                ],
            }

        raise HTTPException(
            status_code=400,
            detail={
                "success": False,
                "errorCode": result.get("errorCode", "cards_list_failed"),
                "errorMessage": result.get("errorMessage", "Failed to list cards"),
            },
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail={"success": False, "errorCode": "server_error", "errorMessage": str(e)},
        )


@app.post("/payment/cards/charge")
async def charge_saved_card(request: ChargeRequest):
    """Charge saved card."""
    try:
        iyzico_request = {
            "locale": "tr",
            "conversationId": request.orderId,
            "price": str(request.amount),
            "paidPrice": str(request.amount),
            "currency": "TRY",
            "installment": "1",
            "basketId": request.orderId,
            "paymentChannel": "WEB",
            "paymentGroup": "PRODUCT",
            "paymentCard": {
                "cardToken": request.cardToken,
                "cardUserKey": request.cardUserKey,
            },
            "buyer": {
                "id": request.buyer.id,
                "name": request.buyer.name,
                "surname": request.buyer.surname,
                "gsmNumber": request.buyer.phone,
                "email": request.buyer.email,
                "identityNumber": request.buyer.identityNumber or "11111111111",
                "registrationAddress": request.buyer.address,
                "ip": request.buyer.ip,
                "city": request.buyer.city,
                "country": request.buyer.country,
            },
            "shippingAddress": {
                "contactName": f"{request.buyer.name} {request.buyer.surname}",
                "city": request.buyer.city,
                "country": request.buyer.country,
                "address": request.buyer.address,
            },
            "billingAddress": {
                "contactName": f"{request.buyer.name} {request.buyer.surname}",
                "city": request.buyer.city,
                "country": request.buyer.country,
                "address": request.buyer.address,
            },
            "basketItems": [
                {
                    "id": item.id,
                    "name": item.name,
                    "category1": item.category,
                    "itemType": "PHYSICAL" if item.itemType == "physical" else "VIRTUAL",
                    "price": str(item.price),
                }
                for item in request.basketItems
            ],
        }

        payment = iyzipay.Payment().create(iyzico_request, options)
        result = payment.read()

        if isinstance(result, str):
            import json
            result = json.loads(result)

        response = map_payment_response(result)
        if not response["success"]:
            raise HTTPException(status_code=400, detail=response)
        return response

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail={"success": False, "errorCode": "server_error", "errorMessage": str(e)},
        )


@app.delete("/payment/cards/{card_token}")
async def delete_saved_card(card_token: str, cardUserKey: str = Query(...)):
    """Delete saved card."""
    try:
        iyzico_request = {
            "locale": "tr",
            "conversationId": str(int(time.time())),
            "cardToken": card_token,
            "cardUserKey": cardUserKey,
        }

        card = iyzipay.Card().delete(iyzico_request, options)
        result = card.read()

        if isinstance(result, str):
            import json
            result = json.loads(result)

        if result.get("status") == "success":
            return {"success": True}

        raise HTTPException(
            status_code=400,
            detail={
                "success": False,
                "errorCode": result.get("errorCode", "card_delete_failed"),
                "errorMessage": result.get("errorMessage", "Failed to delete card"),
            },
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail={"success": False, "errorCode": "server_error", "errorMessage": str(e)},
        )


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "ok", "timestamp": time.time()}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=int(os.getenv("PORT", 3000)))
