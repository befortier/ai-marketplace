# Service / Application Layer

## Responsibility

This layer owns business logic. It coordinates workflows, applies product rules, makes decisions, and composes operations across one or more repositories or external dependencies.

If the question is "what should the system do," the answer belongs here.
If the question is "how do we read or write this data," that belongs in the repository layer.

## What belongs here

- Validating workflow assumptions (does this user exist? is this transition allowed?)
- Orchestrating multiple reads and writes
- Deciding whether a state transition is permitted
- Coordinating transactions across repository calls when needed
- Shaping outcomes that handlers or controllers can consume

## What does not belong here

Raw SQL, database client calls, or row types. If the code is constructing a query string or calling `pool.query`, it has leaked into the wrong layer.

## Design rules

- **Depend on repository interfaces**, not concrete implementations. This is what makes services testable without a database.
- **Inject via constructor**. Keep dependency graphs shallow and visible. Avoid service locators and hidden globals.
- **Readable at the product level**. A reviewer should be able to understand the application behavior without mentally parsing storage details.

A common failure mode is letting services talk directly to the database. It feels faster in the moment but collapses the boundary and spreads persistence knowledge into business code. Another failure mode is services so thin they are pointless wrappers. A good service exists because there is real application behavior to express.

## Example

```ts
export class UserService {
  constructor(private readonly users: UserRepository) {}

  async activateUser(id: string): Promise<User> {
    const user = await this.users.getById(id);

    if (!user) {
      throw new Error(`User ${id} not found`);
    }

    if (user.status === 'active') {
      return user;
    }

    return this.users.updateStatus(id, 'active');
  }
}
```

The business rules live here: if the user is already active, do nothing; if the user exists but is not active, activate them; if they do not exist, throw. That logic does not belong in the repository.

## Testing

Mock repositories. Assert behavior through the repository contract — not SQL, not call counts alone:

```ts
describe('UserService', () => {
  it('returns existing user if already active', async () => {
    const activeUser: User = { id: '1', email: 'a@example.com', status: 'active' };
    const users: UserRepository = {
      getById: vi.fn().mockResolvedValue(activeUser),
      updateStatus: vi.fn(),
    };
    const service = new UserService(users);

    const result = await service.activateUser('1');

    expect(result).toEqual(activeUser);
    expect(users.updateStatus).not.toHaveBeenCalled();
  });

  it('throws when user not found', async () => {
    const users: UserRepository = {
      getById: vi.fn().mockResolvedValue(null),
      updateStatus: vi.fn(),
    };
    const service = new UserService(users);

    await expect(service.activateUser('missing')).rejects.toThrow('User missing not found');
  });

  it('activates a pending user', async () => {
    const pendingUser: User = { id: '1', email: 'a@example.com', status: 'pending' };
    const activatedUser: User = { ...pendingUser, status: 'active' };
    const users: UserRepository = {
      getById: vi.fn().mockResolvedValue(pendingUser),
      updateStatus: vi.fn().mockResolvedValue(activatedUser),
    };
    const service = new UserService(users);

    const result = await service.activateUser('1');

    expect(users.updateStatus).toHaveBeenCalledWith('1', 'active');
    expect(result).toEqual(activatedUser);
  });
});
```

No database setup required. The test verifies business behavior directly.

## Transactions across repositories

When a workflow requires multiple writes to succeed or fail together, coordinate the transaction at the service layer. Pass a transactional client through or use a unit-of-work pattern — but keep the transaction boundary visible and explicit in the service code, not buried in the repository.
