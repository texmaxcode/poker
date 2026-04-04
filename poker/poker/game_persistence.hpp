#ifndef TEXAS_HOLDEM_GYM_GAME_PERSISTENCE_HPP
#define TEXAS_HOLDEM_GYM_GAME_PERSISTENCE_HPP

class game;

class GamePersistence
{
public:
    explicit GamePersistence(game &g);

    void loadPersistedSettings();
    void savePersistedSettings() const;
    void seedMissingPersistedSettings() const;

private:
    void writePersistedSettingsImpl(bool onlyIfMissingKeys) const;
    void save_bankroll_session_to_settings() const;
    bool load_bankroll_session_from_settings();

    game &game_;
};

#endif // TEXAS_HOLDEM_GYM_GAME_PERSISTENCE_HPP
