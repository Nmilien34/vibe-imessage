import { Model, HydratedDocument } from 'mongoose';
import { IUserDocument } from '../types';
interface IUserMethods {
    joinChat(chatId: string): Promise<HydratedDocument<IUserDocument, IUserMethods>>;
    leaveChat(chatId: string): Promise<HydratedDocument<IUserDocument, IUserMethods>>;
}
type UserModel = Model<IUserDocument, {}, IUserMethods>;
declare const User: UserModel;
export default User;
//# sourceMappingURL=User.d.ts.map