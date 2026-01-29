import { Model, HydratedDocument } from 'mongoose';
import { IChatDocument } from '../types';
interface IChatMethods {
    addMember(userId: string): Promise<HydratedDocument<IChatDocument, IChatMethods>>;
    isMember(userId: string): boolean;
    touch(vibeId?: string): Promise<HydratedDocument<IChatDocument, IChatMethods>>;
}
type ChatModel = Model<IChatDocument, {}, IChatMethods>;
declare const Chat: ChatModel;
export default Chat;
//# sourceMappingURL=Chat.d.ts.map