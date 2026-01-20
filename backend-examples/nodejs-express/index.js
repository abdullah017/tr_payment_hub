/**
 * TR Payment Hub - Node.js Express Backend Example
 *
 * This is a reference implementation for the proxy mode backend.
 * Use this as a starting point for your own backend implementation.
 *
 * Features:
 * - Complete iyzico payment integration
 * - Joi validation for all inputs
 * - Secure error handling
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
const Joi = require('joi');
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

// ============================================
// JOI VALIDATION SCHEMAS
// ============================================

// Card validation schema
const cardSchema = Joi.object({
  cardHolderName: Joi.string()
    .min(3)
    .max(100)
    .pattern(/^[a-zA-ZğüşöçıİĞÜŞÖÇ\s]+$/)
    .required()
    .messages({
      'string.pattern.base': 'Card holder name must contain only letters',
    }),
  cardNumber: Joi.string()
    .creditCard()
    .required()
    .messages({
      'string.creditCard': 'Invalid credit card number',
    }),
  expireMonth: Joi.string()
    .pattern(/^(0[1-9]|1[0-2])$/)
    .required()
    .messages({
      'string.pattern.base': 'Expire month must be 01-12',
    }),
  expireYear: Joi.string()
    .pattern(/^20[2-9][0-9]$/)
    .required()
    .messages({
      'string.pattern.base': 'Expire year must be a valid year (20XX)',
    }),
  cvc: Joi.string()
    .pattern(/^[0-9]{3,4}$/)
    .required()
    .messages({
      'string.pattern.base': 'CVC must be 3 or 4 digits',
    }),
  registerCard: Joi.boolean().optional(),
});

// Buyer validation schema
const buyerSchema = Joi.object({
  id: Joi.string().max(50).required(),
  name: Joi.string().min(1).max(50).required(),
  surname: Joi.string().min(1).max(50).required(),
  email: Joi.string().email().required(),
  phone: Joi.string()
    .pattern(/^\+?[0-9]{10,15}$/)
    .required()
    .messages({
      'string.pattern.base': 'Phone must be 10-15 digits',
    }),
  ip: Joi.string()
    .ip({ version: ['ipv4', 'ipv6'] })
    .required(),
  city: Joi.string().min(1).max(50).required(),
  country: Joi.string().min(1).max(50).required(),
  address: Joi.string().min(1).max(255).required(),
  identityNumber: Joi.string()
    .pattern(/^[0-9]{11}$/)
    .optional()
    .messages({
      'string.pattern.base': 'Identity number must be 11 digits',
    }),
});

// Basket item validation schema
const basketItemSchema = Joi.object({
  id: Joi.string().max(50).required(),
  name: Joi.string().min(1).max(100).required(),
  category: Joi.string().min(1).max(100).required(),
  price: Joi.number().positive().required(),
  itemType: Joi.string().valid('physical', 'virtual').required(),
});

// Payment request validation schema
const paymentRequestSchema = Joi.object({
  provider: Joi.string().valid('iyzico', 'paytr', 'param', 'sipay').optional(),
  orderId: Joi.string().max(50).required(),
  amount: Joi.number().positive().required(),
  paidPrice: Joi.number().positive().optional(),
  currency: Joi.string().valid('tryLira', 'TRY', 'usd', 'USD', 'eur', 'EUR').default('tryLira'),
  installment: Joi.number().integer().min(1).max(12).default(1),
  card: cardSchema.required(),
  buyer: buyerSchema.required(),
  basketItems: Joi.array().items(basketItemSchema).min(1).required(),
  callbackUrl: Joi.string().uri().optional(),
});

// 3DS complete validation schema
const threeDSCompleteSchema = Joi.object({
  provider: Joi.string().valid('iyzico', 'paytr', 'param', 'sipay').optional(),
  transactionId: Joi.string().required(),
  callbackData: Joi.object().optional(),
});

// Refund request validation schema
const refundRequestSchema = Joi.object({
  provider: Joi.string().valid('iyzico', 'paytr', 'param', 'sipay').optional(),
  transactionId: Joi.string().required(),
  amount: Joi.number().positive().required(),
  reason: Joi.string().max(255).optional(),
});

// Saved card charge validation schema
const savedCardChargeSchema = Joi.object({
  provider: Joi.string().valid('iyzico', 'paytr', 'param', 'sipay').optional(),
  cardToken: Joi.string().required(),
  cardUserKey: Joi.string().required(),
  orderId: Joi.string().max(50).required(),
  amount: Joi.number().positive().required(),
  buyer: buyerSchema.required(),
  basketItems: Joi.array().items(basketItemSchema).min(1).required(),
});

// Installment query validation schema
const installmentQuerySchema = Joi.object({
  provider: Joi.string().valid('iyzico', 'paytr', 'param', 'sipay').optional(),
  bin: Joi.string()
    .pattern(/^[0-9]{6,8}$/)
    .required()
    .messages({
      'string.pattern.base': 'BIN must be 6-8 digits',
    }),
  amount: Joi.string()
    .pattern(/^[0-9]+(\.[0-9]{1,2})?$/)
    .required(),
});

// ============================================
// VALIDATION MIDDLEWARE
// ============================================

/**
 * Validation middleware factory
 * @param {Joi.Schema} schema - Joi schema to validate against
 * @param {string} source - 'body', 'query', or 'params'
 */
function validate(schema, source = 'body') {
  return (req, res, next) => {
    const data = source === 'body' ? req.body : source === 'query' ? req.query : req.params;

    const { error, value } = schema.validate(data, {
      abortEarly: false,
      stripUnknown: true,
    });

    if (error) {
      const errors = error.details.map((detail) => ({
        field: detail.path.join('.'),
        message: detail.message,
      }));

      return res.status(400).json({
        success: false,
        errorCode: 'validation_error',
        errorMessage: 'Validation failed',
        details: errors,
      });
    }

    // Store validated and sanitized data
    if (source === 'body') {
      req.validatedBody = value;
    } else if (source === 'query') {
      req.validatedQuery = value;
    } else {
      req.validatedParams = value;
    }

    next();
  };
}

// ============================================
// HELPER FUNCTIONS
// ============================================

// Helper: Convert Flutter request to iyzico format
function mapPaymentRequest(body) {
  return {
    locale: Iyzipay.LOCALE.TR,
    conversationId: body.orderId,
    price: String(body.amount),
    paidPrice: String(body.paidPrice || body.amount),
    currency: body.currency === 'tryLira' || body.currency === 'TRY'
      ? Iyzipay.CURRENCY.TRY
      : body.currency,
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
    basketItems: body.basketItems.map((item) => ({
      id: item.id,
      name: item.name,
      category1: item.category,
      itemType:
        item.itemType === 'physical'
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

// ============================================
// ROUTES
// ============================================

// POST /payment/create - Create payment
app.post('/payment/create', validate(paymentRequestSchema), async (req, res) => {
  try {
    const request = mapPaymentRequest(req.validatedBody);

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
app.post('/payment/3ds/init', validate(paymentRequestSchema), async (req, res) => {
  try {
    const body = req.validatedBody;

    if (!body.callbackUrl) {
      return res.status(400).json({
        success: false,
        errorCode: 'validation_error',
        errorMessage: 'callbackUrl is required for 3DS payment',
      });
    }

    const request = {
      ...mapPaymentRequest(body),
      callbackUrl: body.callbackUrl,
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
app.post('/payment/3ds/complete', validate(threeDSCompleteSchema), async (req, res) => {
  try {
    const { transactionId, callbackData } = req.validatedBody;

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
app.get('/payment/installments', validate(installmentQuerySchema, 'query'), async (req, res) => {
  try {
    const { bin, amount } = req.validatedQuery;

    const request = {
      locale: Iyzipay.LOCALE.TR,
      conversationId: Date.now().toString(),
      binNumber: bin,
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
          options: detail.installmentPrices.map((opt) => ({
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
app.post('/payment/refund', validate(refundRequestSchema), async (req, res) => {
  try {
    const { transactionId, amount } = req.validatedBody;

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
    const { userKey } = req.query;

    if (!userKey) {
      return res.status(400).json({
        success: false,
        errorCode: 'validation_error',
        errorMessage: 'userKey query parameter is required',
      });
    }

    const request = {
      locale: Iyzipay.LOCALE.TR,
      conversationId: Date.now().toString(),
      cardUserKey: userKey,
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
          cards: (result.cardDetails || []).map((card) => ({
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
app.post('/payment/cards/charge', validate(savedCardChargeSchema), async (req, res) => {
  try {
    const { cardToken, cardUserKey, orderId, amount, buyer, basketItems } = req.validatedBody;

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
      basketItems: basketItems.map((item) => ({
        id: item.id,
        name: item.name,
        category1: item.category,
        itemType:
          item.itemType === 'physical'
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
    const { userKey } = req.query;

    if (!userKey) {
      return res.status(400).json({
        success: false,
        errorCode: 'validation_error',
        errorMessage: 'userKey query parameter is required',
      });
    }

    const request = {
      locale: Iyzipay.LOCALE.TR,
      conversationId: Date.now().toString(),
      cardToken: req.params.token,
      cardUserKey: userKey,
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

// Global error handler
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({
    success: false,
    errorCode: 'internal_error',
    errorMessage: 'An unexpected error occurred',
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`TR Payment Hub backend running on port ${PORT}`);
  console.log(
    `Using iyzico ${
      process.env.IYZICO_BASE_URL?.includes('sandbox') ? 'sandbox' : 'production'
    } environment`
  );
});
