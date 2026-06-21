const assert = require('node:assert/strict');
const test = require('node:test');

const originalConsoleError = console.error;

test.beforeEach(() => {
  console.error = () => {};
});

test.afterEach(() => {
  console.error = originalConsoleError;
});

function createResponse() {
  return {
    statusCode: undefined,
    body: undefined,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(payload) {
      this.body = payload;
      return this;
    },
  };
}

function loadController(serviceMethods) {
  const servicePath = require.resolve('../dist/services/expense.service');
  const controllerPath = require.resolve('../dist/controllers/expense.controller');

  delete require.cache[controllerPath];

  require.cache[servicePath] = {
    id: servicePath,
    filename: servicePath,
    loaded: true,
    exports: {
      ExpenseService: class {
        getAllExpenses = serviceMethods.getAllExpenses;
        createExpense = serviceMethods.createExpense;
      },
    },
  };

  return require('../dist/controllers/expense.controller');
}

test('getExpenses responds with expenses from the service', async () => {
  const expenses = [{ name: 'Rent', amount: 800, category: 'Housing' }];
  const { getExpenses } = loadController({
    getAllExpenses: async () => expenses,
    createExpense: async () => undefined,
  });
  const res = createResponse();

  await getExpenses({}, res);

  assert.equal(res.statusCode, 200);
  assert.deepEqual(res.body, expenses);
});

test('getExpenses returns 500 when the service fails', async () => {
  const { getExpenses } = loadController({
    getAllExpenses: async () => {
      throw new Error('database unavailable');
    },
    createExpense: async () => undefined,
  });
  const res = createResponse();

  await getExpenses({}, res);

  assert.equal(res.statusCode, 500);
  assert.deepEqual(res.body, { error: 'Failed to fetch expenses' });
});

test('addExpense creates an expense and returns 201', async () => {
  const requestBody = { name: 'Books', amount: 30, category: 'Education' };
  const createdExpense = { id: 'expense-2', ...requestBody };
  const { addExpense } = loadController({
    getAllExpenses: async () => [],
    createExpense: async expense => ({ id: 'expense-2', ...expense }),
  });
  const res = createResponse();

  await addExpense({ body: requestBody }, res);

  assert.equal(res.statusCode, 201);
  assert.deepEqual(res.body, createdExpense);
});
