/**
 * TR Payment Hub - Example Backend Server
 *
 * This backend serves as a proxy between Flutter app and payment providers.
 * API keys are stored securely on the server, never exposed to the client.
 *
 * USAGE:
 * 1. Copy .env.example to .env
 * 2. Fill in your API credentials
 * 3. Run: npm install && npm start
 * 4. Configure Flutter app to use: http://localhost:3000/api/payment
 */

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const crypto = require('crypto-js');
const axios = require('axios');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// ============================================
// CONFIGURATION
// ============================================

const config = {
  iyzico: {
    apiKey: process.env.IYZICO_API_KEY,
    secretKey: process.env.IYZICO_SECRET_KEY,
    baseUrl: process.env.IYZICO_SANDBOX === 'true'
      ? 'https://sandbox-api.iyzipay.com'
      : 'https://api.iyzipay.com',
  },
  paytr: {
    merchantId: process.env.PAYTR_MERCHANT_ID,
    merchantKey: process.env.PAYTR_MERCHANT_KEY,
    merchantSalt: process.env.PAYTR_MERCHANT_SALT,
    baseUrl: 'https://www.paytr.com',
  },
  sipay: {
    merchantId: process.env.SIPAY_MERCHANT_ID,
    apiKey: process.env.SIPAY_API_KEY,
    secretKey: process.env.SIPAY_SECRET_KEY,
    merchantKey: process.env.SIPAY_MERCHANT_KEY,
    baseUrl: process.env.SIPAY_SANDBOX === 'true'
      ? 'https://sandbox.sipay.com.tr'
      : 'https://app.sipay.com.tr',
  },
  param: {
    clientCode: process.env.PARAM_CLIENT_CODE,
    guid: process.env.PARAM_GUID,
    baseUrl: process.env.PARAM_SANDBOX === 'true'
      ? 'https://test-dmz.param.com.tr'
      : 'https://dmz.param.com.tr',
  },
};

// ============================================
// HELPER FUNCTIONS
// ============================================

function generateIyzicoAuth(body) {
  const randomKey = crypto.lib.WordArray.random(8).toString();
  const payload = randomKey + JSON.stringify(body);
  const signature = crypto.HmacSHA256(payload, config.iyzico.secretKey).toString(crypto.enc.Base64);
  return `IYZWS ${config.iyzico.apiKey}:${signature}`;
}

function generatePayTRHash(data) {
  const hashStr = data.join('');
  return crypto.HmacSHA256(hashStr, config.paytr.merchantKey).toString(crypto.enc.Base64);
}

// ============================================
// HEALTH CHECK
// ============================================

app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    providers: {
      iyzico: !!config.iyzico.apiKey,
      paytr: !!config.paytr.merchantId,
      sipay: !!config.sipay.apiKey,
      param: !!config.param.clientCode,
    }
  });
});

// ============================================
// PAYMENT ENDPOINTS
// ============================================

// Create Payment
app.post('/api/payment/create', async (req, res) => {
  try {
    const { provider, ...paymentData } = req.body;

    switch (provider) {
      case 'iyzico':
        return await createIyzicoPayment(paymentData, res);
      case 'paytr':
        return await createPayTRPayment(paymentData, res);
      case 'sipay':
        return await createSipayPayment(paymentData, res);
      case 'param':
        return await createParamPayment(paymentData, res);
      default:
        return res.status(400).json({
          success: false,
          errorCode: 'INVALID_PROVIDER',
          errorMessage: `Unknown provider: ${provider}`
        });
    }
  } catch (error) {
    console.error('Payment error:', error);
    res.status(500).json({
      success: false,
      errorCode: 'SERVER_ERROR',
      errorMessage: error.message
    });
  }
});

// 3DS Init
app.post('/api/payment/3ds/init', async (req, res) => {
  try {
    const { provider, ...paymentData } = req.body;

    switch (provider) {
      case 'iyzico':
        return await init3DSIyzico(paymentData, res);
      case 'sipay':
        return await init3DSSipay(paymentData, res);
      default:
        return res.status(400).json({
          success: false,
          errorCode: 'NOT_SUPPORTED',
          errorMessage: `3DS not supported for: ${provider}`
        });
    }
  } catch (error) {
    console.error('3DS init error:', error);
    res.status(500).json({
      success: false,
      errorCode: 'SERVER_ERROR',
      errorMessage: error.message
    });
  }
});

// 3DS Complete
app.post('/api/payment/3ds/complete', async (req, res) => {
  try {
    const { provider, transactionId, callbackData } = req.body;

    switch (provider) {
      case 'iyzico':
        return await complete3DSIyzico(transactionId, callbackData, res);
      case 'sipay':
        return await complete3DSSipay(transactionId, callbackData, res);
      default:
        return res.status(400).json({
          success: false,
          errorCode: 'NOT_SUPPORTED',
          errorMessage: `3DS complete not supported for: ${provider}`
        });
    }
  } catch (error) {
    console.error('3DS complete error:', error);
    res.status(500).json({
      success: false,
      errorCode: 'SERVER_ERROR',
      errorMessage: error.message
    });
  }
});

// Get Installments
app.get('/api/payment/installments', async (req, res) => {
  try {
    const { provider, bin, amount } = req.query;

    switch (provider) {
      case 'iyzico':
        return await getIyzicoInstallments(bin, amount, res);
      case 'sipay':
        return await getSipayInstallments(bin, amount, res);
      default:
        return res.status(400).json({
          success: false,
          errorCode: 'NOT_SUPPORTED',
          errorMessage: `Installments not supported for: ${provider}`
        });
    }
  } catch (error) {
    console.error('Installments error:', error);
    res.status(500).json({
      success: false,
      errorCode: 'SERVER_ERROR',
      errorMessage: error.message
    });
  }
});

// Refund
app.post('/api/payment/refund', async (req, res) => {
  try {
    const { provider, ...refundData } = req.body;

    switch (provider) {
      case 'iyzico':
        return await processIyzicoRefund(refundData, res);
      case 'paytr':
        return await processPayTRRefund(refundData, res);
      default:
        return res.status(400).json({
          success: false,
          errorCode: 'NOT_SUPPORTED',
          errorMessage: `Refund not supported for: ${provider}`
        });
    }
  } catch (error) {
    console.error('Refund error:', error);
    res.status(500).json({
      success: false,
      errorCode: 'SERVER_ERROR',
      errorMessage: error.message
    });
  }
});

// Get Payment Status
app.get('/api/payment/status/:transactionId', async (req, res) => {
  try {
    const { transactionId } = req.params;
    const { provider } = req.query;

    switch (provider) {
      case 'iyzico':
        return await getIyzicoStatus(transactionId, res);
      case 'paytr':
        return await getPayTRStatus(transactionId, res);
      default:
        return res.status(400).json({
          success: false,
          errorCode: 'NOT_SUPPORTED',
          errorMessage: `Status query not supported for: ${provider}`
        });
    }
  } catch (error) {
    console.error('Status error:', error);
    res.status(500).json({
      success: false,
      errorCode: 'SERVER_ERROR',
      errorMessage: error.message
    });
  }
});

// ============================================
// SAVED CARDS ENDPOINTS
// ============================================

// List Saved Cards
app.get('/api/payment/cards', async (req, res) => {
  try {
    const { provider, userKey } = req.query;

    switch (provider) {
      case 'iyzico':
        return await getIyzicoCards(userKey, res);
      default:
        return res.status(400).json({
          success: false,
          errorCode: 'NOT_SUPPORTED',
          errorMessage: `Saved cards not supported for: ${provider}`
        });
    }
  } catch (error) {
    console.error('Cards error:', error);
    res.status(500).json({
      success: false,
      errorCode: 'SERVER_ERROR',
      errorMessage: error.message
    });
  }
});

// Charge Saved Card
app.post('/api/payment/cards/charge', async (req, res) => {
  try {
    const { provider, ...chargeData } = req.body;

    switch (provider) {
      case 'iyzico':
        return await chargeIyzicoCard(chargeData, res);
      default:
        return res.status(400).json({
          success: false,
          errorCode: 'NOT_SUPPORTED',
          errorMessage: `Saved card charge not supported for: ${provider}`
        });
    }
  } catch (error) {
    console.error('Charge card error:', error);
    res.status(500).json({
      success: false,
      errorCode: 'SERVER_ERROR',
      errorMessage: error.message
    });
  }
});

// Delete Saved Card
app.delete('/api/payment/cards/:cardToken', async (req, res) => {
  try {
    const { cardToken } = req.params;
    const { provider, userKey } = req.query;

    switch (provider) {
      case 'iyzico':
        return await deleteIyzicoCard(userKey, cardToken, res);
      default:
        return res.status(400).json({
          success: false,
          errorCode: 'NOT_SUPPORTED',
          errorMessage: `Card deletion not supported for: ${provider}`
        });
    }
  } catch (error) {
    console.error('Delete card error:', error);
    res.status(500).json({
      success: false,
      errorCode: 'SERVER_ERROR',
      errorMessage: error.message
    });
  }
});

// ============================================
// IYZICO IMPLEMENTATIONS
// ============================================

async function createIyzicoPayment(data, res) {
  const body = {
    locale: 'tr',
    conversationId: data.orderId,
    price: data.amount.toString(),
    paidPrice: data.amount.toString(),
    currency: 'TRY',
    installment: data.installment || 1,
    paymentCard: {
      cardHolderName: data.card.holderName,
      cardNumber: data.card.number.replace(/\s/g, ''),
      expireMonth: data.card.expiryMonth,
      expireYear: data.card.expiryYear,
      cvc: data.card.cvv,
    },
    buyer: {
      id: data.buyer.id,
      name: data.buyer.name,
      surname: data.buyer.surname,
      email: data.buyer.email,
      identityNumber: data.buyer.identityNumber,
      registrationAddress: data.buyer.address,
      ip: data.buyer.ip,
      city: data.buyer.city,
      country: data.buyer.country,
    },
    billingAddress: {
      contactName: `${data.buyer.name} ${data.buyer.surname}`,
      city: data.buyer.city,
      country: data.buyer.country,
      address: data.buyer.address,
    },
    shippingAddress: {
      contactName: `${data.buyer.name} ${data.buyer.surname}`,
      city: data.buyer.city,
      country: data.buyer.country,
      address: data.buyer.address,
    },
    basketItems: data.basketItems.map((item, index) => ({
      id: item.id || `item_${index}`,
      name: item.name,
      category1: item.category,
      itemType: item.itemType === 'physical' ? 'PHYSICAL' : 'VIRTUAL',
      price: item.price.toString(),
    })),
  };

  const response = await axios.post(
    `${config.iyzico.baseUrl}/payment/auth`,
    body,
    {
      headers: {
        'Authorization': generateIyzicoAuth(body),
        'Content-Type': 'application/json',
      },
    }
  );

  const result = response.data;

  res.json({
    success: result.status === 'success',
    transactionId: result.paymentTransactionId,
    paymentId: result.paymentId,
    amount: parseFloat(result.paidPrice),
    errorCode: result.errorCode,
    errorMessage: result.errorMessage,
    rawResponse: result,
  });
}

async function init3DSIyzico(data, res) {
  const body = {
    locale: 'tr',
    conversationId: data.orderId,
    price: data.amount.toString(),
    paidPrice: data.amount.toString(),
    currency: 'TRY',
    installment: data.installment || 1,
    callbackUrl: data.callbackUrl || process.env.IYZICO_CALLBACK_URL,
    paymentCard: {
      cardHolderName: data.card.holderName,
      cardNumber: data.card.number.replace(/\s/g, ''),
      expireMonth: data.card.expiryMonth,
      expireYear: data.card.expiryYear,
      cvc: data.card.cvv,
    },
    buyer: {
      id: data.buyer.id,
      name: data.buyer.name,
      surname: data.buyer.surname,
      email: data.buyer.email,
      identityNumber: data.buyer.identityNumber,
      registrationAddress: data.buyer.address,
      ip: data.buyer.ip,
      city: data.buyer.city,
      country: data.buyer.country,
    },
    billingAddress: {
      contactName: `${data.buyer.name} ${data.buyer.surname}`,
      city: data.buyer.city,
      country: data.buyer.country,
      address: data.buyer.address,
    },
    shippingAddress: {
      contactName: `${data.buyer.name} ${data.buyer.surname}`,
      city: data.buyer.city,
      country: data.buyer.country,
      address: data.buyer.address,
    },
    basketItems: data.basketItems.map((item, index) => ({
      id: item.id || `item_${index}`,
      name: item.name,
      category1: item.category,
      itemType: item.itemType === 'physical' ? 'PHYSICAL' : 'VIRTUAL',
      price: item.price.toString(),
    })),
  };

  const response = await axios.post(
    `${config.iyzico.baseUrl}/payment/3dsecure/initialize`,
    body,
    {
      headers: {
        'Authorization': generateIyzicoAuth(body),
        'Content-Type': 'application/json',
      },
    }
  );

  const result = response.data;

  res.json({
    success: result.status === 'success',
    transactionId: result.conversationId,
    htmlContent: result.threeDSHtmlContent,
    status: result.status === 'success' ? 'pending' : 'failed',
    errorCode: result.errorCode,
    errorMessage: result.errorMessage,
  });
}

async function complete3DSIyzico(transactionId, callbackData, res) {
  // In a real scenario, iyzico sends callback to your server
  // For now, return the callback data as result
  res.json({
    success: callbackData?.status === 'success',
    transactionId: callbackData?.paymentTransactionId,
    paymentId: callbackData?.paymentId,
    amount: parseFloat(callbackData?.paidPrice || 0),
    errorCode: callbackData?.errorCode,
    errorMessage: callbackData?.errorMessage,
  });
}

async function getIyzicoInstallments(bin, amount, res) {
  const body = {
    locale: 'tr',
    binNumber: bin,
    price: amount.toString(),
  };

  const response = await axios.post(
    `${config.iyzico.baseUrl}/payment/iyzipos/installment`,
    body,
    {
      headers: {
        'Authorization': generateIyzicoAuth(body),
        'Content-Type': 'application/json',
      },
    }
  );

  const result = response.data;
  const details = result.installmentDetails?.[0] || {};

  res.json({
    success: result.status === 'success',
    binNumber: bin,
    price: parseFloat(amount),
    cardType: details.cardType === 'CREDIT_CARD' ? 'creditCard' : 'debitCard',
    cardAssociation: (details.cardAssociation || 'visa').toLowerCase(),
    cardFamily: details.cardFamilyName || '',
    bankName: details.bankName || '',
    bankCode: details.bankCode || 0,
    force3DS: details.force3ds === 1,
    forceCVC: details.forceCvc === 1,
    options: (details.installmentPrices || []).map(opt => ({
      installmentNumber: opt.installmentNumber,
      installmentPrice: parseFloat(opt.installmentPrice),
      totalPrice: parseFloat(opt.totalPrice),
    })),
  });
}

async function processIyzicoRefund(data, res) {
  const body = {
    locale: 'tr',
    paymentTransactionId: data.transactionId,
    price: data.amount.toString(),
    ip: data.ip || '127.0.0.1',
  };

  const response = await axios.post(
    `${config.iyzico.baseUrl}/payment/refund`,
    body,
    {
      headers: {
        'Authorization': generateIyzicoAuth(body),
        'Content-Type': 'application/json',
      },
    }
  );

  const result = response.data;

  res.json({
    success: result.status === 'success',
    refundId: result.paymentTransactionId,
    refundedAmount: parseFloat(result.price || data.amount),
    errorCode: result.errorCode,
    errorMessage: result.errorMessage,
  });
}

async function getIyzicoStatus(transactionId, res) {
  const body = {
    locale: 'tr',
    paymentId: transactionId,
  };

  const response = await axios.post(
    `${config.iyzico.baseUrl}/payment/detail`,
    body,
    {
      headers: {
        'Authorization': generateIyzicoAuth(body),
        'Content-Type': 'application/json',
      },
    }
  );

  const result = response.data;
  let status = 'pending';

  if (result.status === 'success') {
    if (result.paymentStatus === 'SUCCESS') status = 'success';
    else if (result.paymentStatus === 'FAILURE') status = 'failed';
    else if (result.paymentStatus === 'REFUND') status = 'refunded';
  }

  res.json({
    success: true,
    status: status,
  });
}

async function getIyzicoCards(userKey, res) {
  const body = {
    locale: 'tr',
    cardUserKey: userKey,
  };

  const response = await axios.post(
    `${config.iyzico.baseUrl}/cardstorage/cards`,
    body,
    {
      headers: {
        'Authorization': generateIyzicoAuth(body),
        'Content-Type': 'application/json',
      },
    }
  );

  const result = response.data;

  res.json({
    success: result.status === 'success',
    cards: (result.cardDetails || []).map(card => ({
      cardToken: card.cardToken,
      cardUserKey: userKey,
      lastFourDigits: card.lastFourDigits,
      cardAssociation: (card.cardAssociation || '').toLowerCase(),
      cardFamily: card.cardFamily,
      cardAlias: card.cardAlias,
      binNumber: card.binNumber,
      bankName: card.cardBankName,
    })),
  });
}

async function chargeIyzicoCard(data, res) {
  const body = {
    locale: 'tr',
    conversationId: data.orderId,
    price: data.amount.toString(),
    paidPrice: data.amount.toString(),
    currency: 'TRY',
    installment: data.installment || 1,
    paymentCard: {
      cardToken: data.cardToken,
      cardUserKey: data.userKey,
    },
    buyer: data.buyer,
    basketItems: [{
      id: 'saved_card_payment',
      name: 'Saved Card Payment',
      category1: 'General',
      itemType: 'VIRTUAL',
      price: data.amount.toString(),
    }],
  };

  const response = await axios.post(
    `${config.iyzico.baseUrl}/payment/auth`,
    body,
    {
      headers: {
        'Authorization': generateIyzicoAuth(body),
        'Content-Type': 'application/json',
      },
    }
  );

  const result = response.data;

  res.json({
    success: result.status === 'success',
    transactionId: result.paymentTransactionId,
    amount: parseFloat(result.paidPrice),
    errorCode: result.errorCode,
    errorMessage: result.errorMessage,
  });
}

async function deleteIyzicoCard(userKey, cardToken, res) {
  const body = {
    locale: 'tr',
    cardUserKey: userKey,
    cardToken: cardToken,
  };

  const response = await axios.post(
    `${config.iyzico.baseUrl}/cardstorage/card`,
    body,
    {
      headers: {
        'Authorization': generateIyzicoAuth(body),
        'Content-Type': 'application/json',
        'X-HTTP-Method-Override': 'DELETE',
      },
    }
  );

  const result = response.data;

  res.json({
    success: result.status === 'success',
    errorCode: result.errorCode,
    errorMessage: result.errorMessage,
  });
}

// ============================================
// PAYTR IMPLEMENTATIONS
// ============================================

async function createPayTRPayment(data, res) {
  // PayTR uses iframe token approach
  res.status(501).json({
    success: false,
    errorCode: 'NOT_IMPLEMENTED',
    errorMessage: 'PayTR requires iframe integration. Use 3DS init endpoint instead.',
  });
}

async function processPayTRRefund(data, res) {
  const hashStr = [
    config.paytr.merchantId,
    data.transactionId,
    data.amount.toString().replace('.', ','),
    config.paytr.merchantSalt,
  ].join('');

  const paytrToken = crypto.HmacSHA256(hashStr, config.paytr.merchantKey).toString(crypto.enc.Base64);

  const formData = new URLSearchParams();
  formData.append('merchant_id', config.paytr.merchantId);
  formData.append('merchant_oid', data.transactionId);
  formData.append('return_amount', data.amount.toString().replace('.', ','));
  formData.append('paytr_token', paytrToken);

  const response = await axios.post(
    `${config.paytr.baseUrl}/odeme/iade`,
    formData,
    {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    }
  );

  const result = response.data;

  res.json({
    success: result.status === 'success',
    refundId: data.transactionId,
    refundedAmount: data.amount,
    errorCode: result.err_no,
    errorMessage: result.err_msg,
  });
}

async function getPayTRStatus(transactionId, res) {
  const hashStr = [
    config.paytr.merchantId,
    transactionId,
    config.paytr.merchantSalt,
  ].join('');

  const paytrToken = crypto.HmacSHA256(hashStr, config.paytr.merchantKey).toString(crypto.enc.Base64);

  const formData = new URLSearchParams();
  formData.append('merchant_id', config.paytr.merchantId);
  formData.append('merchant_oid', transactionId);
  formData.append('paytr_token', paytrToken);

  const response = await axios.post(
    `${config.paytr.baseUrl}/odeme/durum-sorgu`,
    formData,
    {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    }
  );

  const result = response.data;
  let status = 'pending';

  if (result.status === 'success') {
    if (result.payment_status === 'Başarılı') status = 'success';
    else if (result.payment_status === 'Başarısız') status = 'failed';
    else if (result.returns && result.returns.length > 0) status = 'refunded';
  }

  res.json({
    success: true,
    status: status,
  });
}

// ============================================
// SIPAY IMPLEMENTATIONS
// ============================================

let sipayToken = null;
let sipayTokenExpiry = null;

async function getSipayToken() {
  if (sipayToken && sipayTokenExpiry && Date.now() < sipayTokenExpiry) {
    return sipayToken;
  }

  const response = await axios.post(
    `${config.sipay.baseUrl}/ccpayment/api/token`,
    {
      app_id: config.sipay.apiKey,
      app_secret: config.sipay.secretKey,
    }
  );

  sipayToken = response.data.data.token;
  sipayTokenExpiry = Date.now() + (response.data.data.expires_at * 1000) - 60000;

  return sipayToken;
}

async function createSipayPayment(data, res) {
  const token = await getSipayToken();

  const response = await axios.post(
    `${config.sipay.baseUrl}/ccpayment/api/paySmart2D`,
    {
      merchant_key: config.sipay.merchantKey,
      invoice_id: data.orderId,
      total: data.amount,
      currency_code: 'TRY',
      cc_holder_name: data.card.holderName,
      cc_no: data.card.number.replace(/\s/g, ''),
      expiry_month: data.card.expiryMonth,
      expiry_year: data.card.expiryYear,
      cvv: data.card.cvv,
      installments_number: data.installment || 1,
    },
    {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
    }
  );

  const result = response.data;

  res.json({
    success: result.status_code === 100,
    transactionId: result.data?.order_no,
    amount: data.amount,
    errorCode: result.status_code?.toString(),
    errorMessage: result.status_description,
  });
}

async function init3DSSipay(data, res) {
  const token = await getSipayToken();

  const response = await axios.post(
    `${config.sipay.baseUrl}/ccpayment/api/paySmart3D`,
    {
      merchant_key: config.sipay.merchantKey,
      invoice_id: data.orderId,
      total: data.amount,
      currency_code: 'TRY',
      cc_holder_name: data.card.holderName,
      cc_no: data.card.number.replace(/\s/g, ''),
      expiry_month: data.card.expiryMonth,
      expiry_year: data.card.expiryYear,
      cvv: data.card.cvv,
      installments_number: data.installment || 1,
      return_url: data.callbackUrl || process.env.SIPAY_CALLBACK_URL,
    },
    {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
    }
  );

  const result = response.data;

  res.json({
    success: result.status_code === 100,
    transactionId: data.orderId,
    htmlContent: result.data?.redirect_url,
    status: result.status_code === 100 ? 'pending' : 'failed',
    errorCode: result.status_code?.toString(),
    errorMessage: result.status_description,
  });
}

async function complete3DSSipay(transactionId, callbackData, res) {
  res.json({
    success: callbackData?.status === 'success',
    transactionId: callbackData?.order_no,
    amount: parseFloat(callbackData?.total || 0),
    errorCode: callbackData?.status_code,
    errorMessage: callbackData?.status_description,
  });
}

async function getSipayInstallments(bin, amount, res) {
  const token = await getSipayToken();

  const response = await axios.post(
    `${config.sipay.baseUrl}/ccpayment/api/getpos`,
    {
      merchant_key: config.sipay.merchantKey,
      credit_card: bin,
      amount: amount,
      currency_code: 'TRY',
    },
    {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
    }
  );

  const result = response.data;
  const posData = result.data?.[0] || {};

  res.json({
    success: result.status_code === 100,
    binNumber: bin,
    price: parseFloat(amount),
    cardType: posData.card_type === 'credit' ? 'creditCard' : 'debitCard',
    cardAssociation: (posData.card_program || 'visa').toLowerCase(),
    cardFamily: posData.card_family || '',
    bankName: posData.bank_name || '',
    bankCode: posData.bank_code || 0,
    force3DS: true,
    forceCVC: true,
    options: (posData.installments || []).map(opt => ({
      installmentNumber: opt.installment_count,
      installmentPrice: parseFloat(opt.amount_per_installment),
      totalPrice: parseFloat(opt.total_amount),
    })),
  });
}

// ============================================
// PARAM IMPLEMENTATIONS
// ============================================

async function createParamPayment(data, res) {
  // Param uses SOAP/XML API - simplified implementation
  res.status(501).json({
    success: false,
    errorCode: 'NOT_IMPLEMENTED',
    errorMessage: 'Param SOAP implementation not included in this example.',
  });
}

// ============================================
// START SERVER
// ============================================

app.listen(PORT, () => {
  console.log(`
╔════════════════════════════════════════════════════════════╗
║         TR Payment Hub - Backend Server                    ║
╠════════════════════════════════════════════════════════════╣
║  Server running on: http://localhost:${PORT}                  ║
║  API Base URL: http://localhost:${PORT}/api/payment           ║
╠════════════════════════════════════════════════════════════╣
║  Configured Providers:                                     ║
║  - iyzico:  ${config.iyzico.apiKey ? '✓ Ready' : '✗ Not configured'}                                  ║
║  - PayTR:   ${config.paytr.merchantId ? '✓ Ready' : '✗ Not configured'}                                  ║
║  - Sipay:   ${config.sipay.apiKey ? '✓ Ready' : '✗ Not configured'}                                  ║
║  - Param:   ${config.param.clientCode ? '✓ Ready' : '✗ Not configured'}                                  ║
╚════════════════════════════════════════════════════════════╝
  `);
});
