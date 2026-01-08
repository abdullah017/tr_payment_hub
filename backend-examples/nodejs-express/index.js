/**
 * TR Payment Hub - Node.js Express Backend Example
 *
 * This is a reference implementation for the proxy mode backend.
 * Use this as a starting point for your own backend implementation.
 *
 * Endpoints:
 * - POST /payment/create      - Create a payment
 * - POST /payment/3ds/init    - Initialize 3DS payment
 * - POST /payment/3ds/complete - Complete 3DS payment
 * - GET  /payment/installments - Query installment options
 * - POST /payment/refund      - Process refund
 * - GET  /payment/status/:id  - Get payment status
 * - GET  /payment/cards       - List saved cards
 * - POST /payment/cards/charge - Charge saved card
 * - DELETE /payment/cards/:token - Delete saved card
 */

require('dotenv').config();
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const Iyzipay = require('iyzipay');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Initialize iyzico client
const iyzipay = new Iyzipay({
  apiKey: process.env.IYZICO_API_KEY,
  secretKey: process.env.IYZICO_SECRET_KEY,
  uri: process.env.IYZICO_BASE_URL || 'https://sandbox-api.iyzipay.com',
});

// Helper: Convert Flutter request to iyzico format
function mapPaymentRequest(body) {
  return {
    locale: Iyzipay.LOCALE.TR,
    conversationId: body.orderId,
    price: String(body.amount),
    paidPrice: String(body.paidPrice || body.amount),
    currency: body.currency === 'tryLira' ? Iyzipay.CURRENCY.TRY : body.currency,
    installment: body.installment || 1,
    basketId: body.orderId,
    paymentChannel: Iyzipay.PAYMENT_CHANNEL.WEB,
    paymentGroup: Iyzipay.PAYMENT_GROUP.PRODUCT,
    paymentCard: {
      cardHolderName: body.card.cardHolderName,
      cardNumber: body.card.cardNumber,
      expireMonth: body.card.expireMonth,
      expireYear: body.card.expireYear,
      cvc: body.card.cvc,
      registerCard: body.card.registerCard ? '1' : '0',
    },
    buyer: {
      id: body.buyer.id,
      name: body.buyer.name,
      surname: body.buyer.surname,
      gsmNumber: body.buyer.phone,
      email: body.buyer.email,
      identityNumber: body.buyer.identityNumber || '11111111111',
      registrationAddress: body.buyer.address,
      ip: body.buyer.ip,
      city: body.buyer.city,
      country: body.buyer.country,
    },
    shippingAddress: {
      contactName: `${body.buyer.name} ${body.buyer.surname}`,
      city: body.buyer.city,
      country: body.buyer.country,
      address: body.buyer.address,
    },
    billingAddress: {
      contactName: `${body.buyer.name} ${body.buyer.surname}`,
      city: body.buyer.city,
      country: body.buyer.country,
      address: body.buyer.address,
    },
    basketItems: body.basketItems.map((item, index) => ({
      id: item.id,
      name: item.name,
      category1: item.category,
      itemType: item.itemType === 'physical'
        ? Iyzipay.BASKET_ITEM_TYPE.PHYSICAL
        : Iyzipay.BASKET_ITEM_TYPE.VIRTUAL,
      price: String(item.price),
    })),
  };
}

// Helper: Map iyzico response to Flutter format
function mapPaymentResponse(result) {
  if (result.status === 'success') {
    return {
      success: true,
      transactionId: result.paymentId,
      paymentId: result.paymentId,
      amount: parseFloat(result.price),
      paidAmount: parseFloat(result.paidPrice),
      installment: result.installment,
      cardType: result.cardType,
      cardAssociation: result.cardAssociation,
      binNumber: result.binNumber,
      lastFourDigits: result.lastFourDigits,
    };
  }
  return {
    success: false,
    errorCode: result.errorCode,
    errorMessage: result.errorMessage,
  };
}

// POST /payment/create - Create payment
app.post('/payment/create', async (req, res) => {
  try {
    const request = mapPaymentRequest(req.body);

    iyzipay.payment.create(request, (err, result) => {
      if (err) {
        return res.status(500).json({
          success: false,
          errorCode: 'network_error',
          errorMessage: err.message,
        });
      }
      const response = mapPaymentResponse(result);
      res.status(response.success ? 200 : 400).json(response);
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      errorCode: 'server_error',
      errorMessage: error.message,
    });
  }
});

// POST /payment/3ds/init - Initialize 3DS payment
app.post('/payment/3ds/init', async (req, res) => {
  try {
    const request = {
      ...mapPaymentRequest(req.body),
      callbackUrl: req.body.callbackUrl,
    };

    iyzipay.threedsInitialize.create(request, (err, result) => {
      if (err) {
        return res.status(500).json({
          success: false,
          errorCode: 'network_error',
          errorMessage: err.message,
        });
      }

      if (result.status === 'success') {
        res.json({
          success: true,
          status: 'pending',
          transactionId: result.conversationId,
          htmlContent: result.threeDSHtmlContent,
        });
      } else {
        res.status(400).json({
          success: false,
          errorCode: result.errorCode,
          errorMessage: result.errorMessage,
        });
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      errorCode: 'server_error',
      errorMessage: error.message,
    });
  }
});

// POST /payment/3ds/complete - Complete 3DS payment
app.post('/payment/3ds/complete', async (req, res) => {
  try {
    const { transactionId, callbackData } = req.body;

    const request = {
      locale: Iyzipay.LOCALE.TR,
      conversationId: transactionId,
      paymentId: callbackData?.paymentId || transactionId,
    };

    iyzipay.threedsPayment.create(request, (err, result) => {
      if (err) {
        return res.status(500).json({
          success: false,
          errorCode: 'network_error',
          errorMessage: err.message,
        });
      }
      const response = mapPaymentResponse(result);
      res.status(response.success ? 200 : 400).json(response);
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      errorCode: 'server_error',
      errorMessage: error.message,
    });
  }
});

// GET /payment/installments - Query installment options
app.get('/payment/installments', async (req, res) => {
  try {
    const { binNumber, amount } = req.query;

    const request = {
      locale: Iyzipay.LOCALE.TR,
      conversationId: Date.now().toString(),
      binNumber: binNumber,
      price: amount,
    };

    iyzipay.installmentInfo.retrieve(request, (err, result) => {
      if (err) {
        return res.status(500).json({
          success: false,
          errorCode: 'network_error',
          errorMessage: err.message,
        });
      }

      if (result.status === 'success' && result.installmentDetails?.length > 0) {
        const detail = result.installmentDetails[0];
        res.json({
          success: true,
          binNumber: detail.binNumber,
          bankName: detail.bankName,
          bankCode: detail.bankCode,
          cardType: detail.cardType,
          cardAssociation: detail.cardAssociation,
          options: detail.installmentPrices.map(opt => ({
            installmentNumber: opt.installmentNumber,
            installmentPrice: parseFloat(opt.installmentPrice),
            totalPrice: parseFloat(opt.totalPrice),
          })),
        });
      } else {
        res.status(400).json({
          success: false,
          errorCode: result.errorCode || 'no_installments',
          errorMessage: result.errorMessage || 'No installment options found',
        });
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      errorCode: 'server_error',
      errorMessage: error.message,
    });
  }
});

// POST /payment/refund - Process refund
app.post('/payment/refund', async (req, res) => {
  try {
    const { transactionId, amount } = req.body;

    const request = {
      locale: Iyzipay.LOCALE.TR,
      conversationId: Date.now().toString(),
      paymentTransactionId: transactionId,
      price: String(amount),
      currency: Iyzipay.CURRENCY.TRY,
    };

    iyzipay.refund.create(request, (err, result) => {
      if (err) {
        return res.status(500).json({
          success: false,
          errorCode: 'network_error',
          errorMessage: err.message,
        });
      }

      if (result.status === 'success') {
        res.json({
          success: true,
          refundId: result.paymentTransactionId,
          refundedAmount: parseFloat(result.price),
        });
      } else {
        res.status(400).json({
          success: false,
          errorCode: result.errorCode,
          errorMessage: result.errorMessage,
        });
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      errorCode: 'server_error',
      errorMessage: error.message,
    });
  }
});

// GET /payment/status/:id - Get payment status
app.get('/payment/status/:id', async (req, res) => {
  try {
    const request = {
      locale: Iyzipay.LOCALE.TR,
      conversationId: Date.now().toString(),
      paymentId: req.params.id,
    };

    iyzipay.payment.retrieve(request, (err, result) => {
      if (err) {
        return res.status(500).json({
          success: false,
          errorCode: 'network_error',
          errorMessage: err.message,
        });
      }

      if (result.status === 'success') {
        res.json({
          success: true,
          status: result.paymentStatus === '1' ? 'success' : 'pending',
        });
      } else {
        res.status(400).json({
          success: false,
          errorCode: result.errorCode,
          errorMessage: result.errorMessage,
        });
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      errorCode: 'server_error',
      errorMessage: error.message,
    });
  }
});

// GET /payment/cards - List saved cards
app.get('/payment/cards', async (req, res) => {
  try {
    const { cardUserKey } = req.query;

    const request = {
      locale: Iyzipay.LOCALE.TR,
      conversationId: Date.now().toString(),
      cardUserKey: cardUserKey,
    };

    iyzipay.card.retrieve(request, (err, result) => {
      if (err) {
        return res.status(500).json({
          success: false,
          errorCode: 'network_error',
          errorMessage: err.message,
        });
      }

      if (result.status === 'success') {
        res.json({
          success: true,
          cards: (result.cardDetails || []).map(card => ({
            cardToken: card.cardToken,
            cardAlias: card.cardAlias,
            binNumber: card.binNumber,
            lastFourDigits: card.lastFourDigits,
            cardType: card.cardType,
            cardAssociation: card.cardAssociation,
          })),
        });
      } else {
        res.status(400).json({
          success: false,
          errorCode: result.errorCode,
          errorMessage: result.errorMessage,
        });
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      errorCode: 'server_error',
      errorMessage: error.message,
    });
  }
});

// POST /payment/cards/charge - Charge saved card
app.post('/payment/cards/charge', async (req, res) => {
  try {
    const { cardToken, cardUserKey, orderId, amount, buyer, basketItems } = req.body;

    const request = {
      locale: Iyzipay.LOCALE.TR,
      conversationId: orderId,
      price: String(amount),
      paidPrice: String(amount),
      currency: Iyzipay.CURRENCY.TRY,
      installment: 1,
      basketId: orderId,
      paymentChannel: Iyzipay.PAYMENT_CHANNEL.WEB,
      paymentGroup: Iyzipay.PAYMENT_GROUP.PRODUCT,
      paymentCard: {
        cardToken: cardToken,
        cardUserKey: cardUserKey,
      },
      buyer: {
        id: buyer.id,
        name: buyer.name,
        surname: buyer.surname,
        gsmNumber: buyer.phone,
        email: buyer.email,
        identityNumber: buyer.identityNumber || '11111111111',
        registrationAddress: buyer.address,
        ip: buyer.ip,
        city: buyer.city,
        country: buyer.country,
      },
      shippingAddress: {
        contactName: `${buyer.name} ${buyer.surname}`,
        city: buyer.city,
        country: buyer.country,
        address: buyer.address,
      },
      billingAddress: {
        contactName: `${buyer.name} ${buyer.surname}`,
        city: buyer.city,
        country: buyer.country,
        address: buyer.address,
      },
      basketItems: basketItems.map(item => ({
        id: item.id,
        name: item.name,
        category1: item.category,
        itemType: item.itemType === 'physical'
          ? Iyzipay.BASKET_ITEM_TYPE.PHYSICAL
          : Iyzipay.BASKET_ITEM_TYPE.VIRTUAL,
        price: String(item.price),
      })),
    };

    iyzipay.payment.create(request, (err, result) => {
      if (err) {
        return res.status(500).json({
          success: false,
          errorCode: 'network_error',
          errorMessage: err.message,
        });
      }
      const response = mapPaymentResponse(result);
      res.status(response.success ? 200 : 400).json(response);
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      errorCode: 'server_error',
      errorMessage: error.message,
    });
  }
});

// DELETE /payment/cards/:token - Delete saved card
app.delete('/payment/cards/:token', async (req, res) => {
  try {
    const { cardUserKey } = req.query;

    const request = {
      locale: Iyzipay.LOCALE.TR,
      conversationId: Date.now().toString(),
      cardToken: req.params.token,
      cardUserKey: cardUserKey,
    };

    iyzipay.card.delete(request, (err, result) => {
      if (err) {
        return res.status(500).json({
          success: false,
          errorCode: 'network_error',
          errorMessage: err.message,
        });
      }

      if (result.status === 'success') {
        res.json({ success: true });
      } else {
        res.status(400).json({
          success: false,
          errorCode: result.errorCode,
          errorMessage: result.errorMessage,
        });
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      errorCode: 'server_error',
      errorMessage: error.message,
    });
  }
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Start server
app.listen(PORT, () => {
  console.log(`TR Payment Hub backend running on port ${PORT}`);
  console.log(`Using iyzico ${process.env.IYZICO_BASE_URL?.includes('sandbox') ? 'sandbox' : 'production'} environment`);
});
