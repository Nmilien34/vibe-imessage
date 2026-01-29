import { Model } from 'mongoose';
import { IVibe } from '../types';
export declare const FEED_EXPIRATION_DAYS = 1;
export declare const HISTORY_RETENTION_DAYS = 15;
interface IVibeModel extends Model<IVibe> {
    createWithExpiration(data: Partial<IVibe>): Promise<IVibe>;
}
declare const Vibe: IVibeModel;
export default Vibe;
//# sourceMappingURL=Vibe.d.ts.map