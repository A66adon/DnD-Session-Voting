package ds.dnd.voting.repositories;

import ds.dnd.voting.model.VotingWeek;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface VotingWeekRepository extends JpaRepository<VotingWeek, Long> {

    @Query("SELECT w FROM VotingWeek w WHERE w.deadline >= :currentDate ORDER BY w.deadline ASC")
    Optional<VotingWeek> findCurrentWeek(LocalDate currentDate);

    List<VotingWeek> findAllByOrderByDeadlineDesc();
}
