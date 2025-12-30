package ds.dnd.voting.repositories;

import ds.dnd.voting.model.VotingWeek;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

public interface VotingWeekRepository extends JpaRepository<VotingWeek, Long> {

    Optional<VotingWeek> findByActiveTrue();

    List<VotingWeek> findAllByOrderByDeadlineDesc();

    @Modifying
    @Transactional
    @Query("UPDATE VotingWeek w SET w.active = false WHERE w.active = true")
    void deactivateAll();
}
