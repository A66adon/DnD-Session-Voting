package ds.dnd.voting.repositories;

import ds.dnd.voting.model.VotingWeek;
import org.springframework.data.jpa.repository.JpaRepository;

public interface VotingWeekRepository extends JpaRepository<VotingWeek, Long> {
}
