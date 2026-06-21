const assert = require('node:assert/strict');
const test = require('node:test');

const originalConsoleLog = console.log;

test.beforeEach(() => {
  console.log = () => {};
});

test.afterEach(() => {
  console.log = originalConsoleLog;
});

function loadExpenseService({ cachedExpenses, dbExpenses, createdExpense } = {}) {
  const expenseModelPath = require.resolve('../dist/models/expense.model');
  const redisPath = require.resolve('../dist/config/redis');
  const servicePath = require.resolve('../dist/services/expense.service');

  delete require.cache[servicePath];

  const redisCalls = {
    get: [],
    set: [],
    del: [],
  };

  const redisMock = {
    get: async key => {
      redisCalls.get.push(key);
      return cachedExpenses ?? null;
    },
    set: async (...args) => {
      redisCalls.set.push(args);
    },
    del: async key => {
      redisCalls.del.push(key);
    },
  };

  const expenseModelMock = {
    find: async () => dbExpenses ?? [],
    create: async expense => createdExpense ?? { id: 'created-id', ...expense },
  };

  require.cache[redisPath] = {
    id: redisPath,
    filename: redisPath,
    loaded: true,
    exports: { __esModule: true, default: redisMock },
  };

  require.cache[expenseModelPath] = {
    id: expenseModelPath,
    filename: expenseModelPath,
    loaded: true,
    exports: { __esModule: true, default: expenseModelMock },
  };

  const { ExpenseService } = require('../dist/services/expense.service');
  return { service: new ExpenseService(), redisCalls };
}

test('getAllExpenses returns cached expenses without querying MongoDB', async () => {
  const cached = [{ name: 'Coffee', amount: 4, category: 'Food' }];
  const { service, redisCalls } = loadExpenseService({
    cachedExpenses: JSON.stringify(cached),
    dbExpenses: [{ name: 'Should not be returned', amount: 100, category: 'Other' }],
  });

  const result = await service.getAllExpenses();

  assert.deepEqual(result, cached);
  assert.deepEqual(redisCalls.get, ['expenses']);
  assert.deepEqual(redisCalls.set, []);
});

test('getAllExpenses stores MongoDB result in Redis when cache is empty', async () => {
  const dbExpenses = [{ name: 'Groceries', amount: 25, category: 'Food' }];
  const { service, redisCalls } = loadExpenseService({ dbExpenses });

  const result = await service.getAllExpenses();

  assert.deepEqual(result, dbExpenses);
  assert.deepEqual(redisCalls.get, ['expenses']);
  assert.equal(redisCalls.set.length, 1);
  assert.deepEqual(redisCalls.set[0], ['expenses', JSON.stringify(dbExpenses), 'EX', 300]);
});

test('createExpense creates a record and invalidates the expenses cache', async () => {
  const input = { name: 'Taxi', amount: 12, category: 'Transport' };
  const createdExpense = { id: 'expense-1', ...input };
  const { service, redisCalls } = loadExpenseService({ createdExpense });

  const result = await service.createExpense(input);

  assert.deepEqual(result, createdExpense);
  assert.deepEqual(redisCalls.del, ['expenses']);
});
